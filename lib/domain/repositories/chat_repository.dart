import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 1. Get or Create Chat Room (prevents duplicates)
  Future<String> getOrCreateChatRoom(String myUid, String friendUid) async {
    final existing = await _firestore.collection('chat_rooms')
        .where('members', arrayContains: myUid)
        .get();
    
    for (final doc in existing.docs) {
      final members = List<String>.from(doc['members'] ?? []);
      if (members.contains(friendUid)) {
        return doc.id;
      }
    }
    
    final roomRef = await _firestore.collection('chat_rooms').add({
      'members': [myUid, friendUid],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    
    return roomRef.id;
  }

  // 2. Send Message — uses local Timestamp for immediate time display
  Future<void> sendMessage(String roomId, String senderUid, String text) async {
    final now = Timestamp.now(); // Local timestamp for immediate display

    _firestore.collection('chat_rooms').doc(roomId).collection('messages').add({
      'senderUid': senderUid,
      'text': text,
      'createdAt': now,
      'isRead': false,
    }).then((_) => debugPrint('✉️ Message sent'))
      .catchError((e) => debugPrint('⚠️ Message send error: $e'));

    // Update room's last message
    _firestore.collection('chat_rooms').doc(roomId).update({
      'lastMessage': text,
      'lastMessageTime': now,
    }).catchError((e) => debugPrint('⚠️ Room update error: $e'));
  }

  // 3. Stream Messages (real-time)
  Stream<QuerySnapshot> getMessages(String roomId) {
    return _firestore.collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  // 4. Stream My Rooms
  Stream<QuerySnapshot> getMyRooms(String uid) {
     return _firestore.collection('chat_rooms')
        .where('members', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // 5. Mark messages as read (for specific sender's messages)
  Future<void> markMessagesAsRead(String roomId, String myUid) async {
    try {
      final snapshot = await _firestore
          .collection('chat_rooms').doc(roomId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final unreadFromOther = snapshot.docs
          .where((doc) => doc['senderUid'] != myUid)
          .toList();

      if (unreadFromOther.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unreadFromOther) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.commit()
          .then((_) => debugPrint('👁️ Marked ${unreadFromOther.length} messages as read'))
          .catchError((e) => debugPrint('⚠️ Mark read error: $e'));
    } catch (e) {
      debugPrint('⚠️ markMessagesAsRead skipped: $e');
    }
  }

  // 6. Mark messages from a specific sender as read (for bot read-receipt)
  Future<void> markMessagesFromSenderAsRead(String roomId, String senderUid) async {
    try {
      final snapshot = await _firestore
          .collection('chat_rooms').doc(roomId)
          .collection('messages')
          .where('senderUid', isEqualTo: senderUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.commit()
          .then((_) => debugPrint('👁️ Bot read ${snapshot.docs.length} of your messages'))
          .catchError((e) => debugPrint('⚠️ Bot mark read error: $e'));
    } catch (e) {
      debugPrint('⚠️ markMessagesFromSenderAsRead skipped: $e');
    }
  }
}
