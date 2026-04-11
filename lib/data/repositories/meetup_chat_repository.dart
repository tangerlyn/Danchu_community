import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/chat_message.dart';

class MeetupChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  MeetupChatRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadImage(String postId, String uid, File file) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.jpg';
      final storageRef = _storage.ref().child('chat_images/$postId/$fileName');

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('⚠️ uploadImage error: $e');
      rethrow;
    }
  }

  CollectionReference _chatCollection(String postId) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('chat');
  }

  DocumentReference _chatReadDoc(String postId, String uid) {
    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('chat_read')
        .doc(uid);
  }

  /// Send a chat message
  Future<void> sendMessage(String postId, ChatMessage message) async {
    try {
      await _chatCollection(postId).doc(message.id).set(message.toJson());
    } catch (e) {
      debugPrint('⚠️ sendMessage error: $e');
      rethrow;
    }
  }

  Future<void> sendSystemMessage(String postId, String message) async {
    final msgId = _chatCollection(postId).doc().id;
    await _chatCollection(postId).doc(msgId).set({
      'senderUid': 'system',
      'senderNickname': 'system',
      'message': message,
      'type': 'system',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [],
      'imageUrls': [],
    });
  }

  /// Get new document ID for chat message
  String getNewMessageId(String postId) {
    return _chatCollection(postId).doc().id;
  }

  /// Stream chat messages (oldest first for chat display)
  Stream<List<ChatMessage>> getMessagesStream(
    String postId, {
    DateTime? joinedAt,
  }) {
    Query query = _chatCollection(
      postId,
    ).orderBy('createdAt', descending: false);

    if (joinedAt != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(joinedAt),
      );
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => ChatMessage.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList(),
    );
  }

  /// Update the last read timestamp for a user in a chat room
  Future<void> updateLastReadAt(String postId, String uid) async {
    try {
      await _chatReadDoc(postId, uid).set({
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Batch update readBy for up to 100 recent messages
      final recentMessages = await _chatCollection(
        postId,
      ).orderBy('createdAt', descending: true).limit(100).get();

      final batch = _firestore.batch();
      int updateCount = 0;

      for (var doc in recentMessages.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final senderUid = data['senderUid'] as String?;
        final readBy = List<String>.from(data['readBy'] ?? []);

        if (senderUid != uid && !readBy.contains(uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([uid]),
          });
          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        debugPrint(
          '👁️ Batch updated $updateCount messages read receipts for $uid',
        );
      }
    } catch (e) {
      debugPrint('⚠️ updateLastReadAt error: $e');
    }
  }

  /// Get the joinedAt timestamp from the participants subcollection
  Future<DateTime?> getParticipantJoinedAt(String postId, String uid) async {
    try {
      final doc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('participants')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final timestamp = data?['joinedAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      debugPrint('⚠️ getParticipantJoinedAt error: $e');
    }
    return null;
  }

  /// Get the last read timestamp for a user
  Future<DateTime?> getLastReadAt(String postId, String uid) async {
    try {
      final doc = await _chatReadDoc(postId, uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final timestamp = data?['lastReadAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      debugPrint('⚠️ getLastReadAt error: $e');
    }
    return null;
  }

  /// Get the number of unread messages for a user in a chat room
  Future<int> getUnreadCount(String postId, String uid) async {
    try {
      final lastReadAt = await getLastReadAt(postId, uid);
      Query query = _chatCollection(postId);
      if (lastReadAt != null) {
        query = query.where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(lastReadAt),
        );
      }
      // Exclude own messages
      final snapshot = await query.get();
      return snapshot.docs
          .where(
            (doc) => (doc.data() as Map<String, dynamic>)['senderUid'] != uid,
          )
          .length;
    } catch (e) {
      debugPrint('⚠️ getUnreadCount error: $e');
      return 0;
    }
  }

  /// Stream real-time number of unread messages for a user in a chat room
  Stream<int> getUnreadCountStream(String postId, String uid) {
    // A stream that yields the baseline `lastReadAt` (or `joinedAt` if null).
    final baselineStream = _chatReadDoc(postId, uid).snapshots().asyncMap((
      snapshot,
    ) async {
      DateTime? baseline;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('lastReadAt')) {
          baseline = (data['lastReadAt'] as Timestamp?)?.toDate();
        }
      }
      if (baseline != null) return baseline;

      // Fallback: if they never read it, use the time they joined
      return await getParticipantJoinedAt(postId, uid);
    });

    // Every time the baseline updates (e.g. user reads messages),
    // we create a new query stream for messages newer than that baseline.
    return baselineStream.switchMap((baseline) {
      Query query = _chatCollection(postId);
      if (baseline != null) {
        query = query.where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(baseline),
        );
      }
      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .where(
              (doc) => (doc.data() as Map<String, dynamic>)['senderUid'] != uid,
            )
            .length;
      });
    });
  }

  /// Get the last message in a chat room
  Future<ChatMessage?> getLastMessage(String postId) async {
    try {
      final snapshot = await _chatCollection(
        postId,
      ).orderBy('createdAt', descending: true).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return ChatMessage.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint('⚠️ getLastMessage error: $e');
    }
    return null;
  }

  /// Stream the last message for real-time updates in chat list
  Stream<ChatMessage?> getLastMessageStream(String postId) {
    return _chatCollection(
      postId,
    ).orderBy('createdAt', descending: true).limit(1).snapshots().map((
      snapshot,
    ) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return ChatMessage.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// Get/set chat mute status
  Future<bool> getChatMuted(String postId, String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_settings')
          .doc(postId)
          .get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>?)?['chatMuted'] ?? false;
      }
    } catch (e) {
      debugPrint('⚠️ getChatMuted error: $e');
    }
    return false;
  }

  Future<void> toggleChatMuted(String postId, String uid) async {
    try {
      final currentMuted = await getChatMuted(postId, uid);
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_settings')
          .doc(postId)
          .set({
            'chatMuted': !currentMuted,
            'mutedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ toggleChatMuted error: $e');
      rethrow;
    }
  }
}
