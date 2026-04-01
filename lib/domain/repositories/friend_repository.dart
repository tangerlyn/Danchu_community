import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_profile.dart';
import 'chat_repository.dart';

class FriendRepository {
  final FirebaseFirestore _firestore;
  
  FriendRepository({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? 'test_user_1';

  // 1. Search Users by nickname or dogName (prefix search)
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    final String searchLower = query.trim().toLowerCase();
    
    try {
      // Fetch all users and filter client-side for flexible search
      // (Firestore doesn't support OR queries across fields with prefix matching natively)
      final snapshot = await _firestore.collection('users').get();
      
      final results = <UserProfile>[];
      for (final doc in snapshot.docs) {
        // Skip self
        if (doc.id == _myUid) continue;
        
        final profile = UserProfile.fromFirestore(doc);
        final nickLower = profile.nickname.toLowerCase();
        final dogLower = profile.dogName.toLowerCase();
        
        if (nickLower.contains(searchLower) || dogLower.contains(searchLower)) {
          results.add(profile);
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('❌ Search failed: $e');
      return [];
    }
  }

  // 2. Add Friend (bidirectional) + auto-create chat room
  Future<void> addFriend(String friendUid) async {
    final myUid = _myUid;
    
    final batch = _firestore.batch();
    
    // My friends subcollection
    final myFriendRef = _firestore
        .collection('users').doc(myUid)
        .collection('friends').doc(friendUid);
    batch.set(myFriendRef, {
      'friendUid': friendUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Their friends subcollection
    final theirFriendRef = _firestore
        .collection('users').doc(friendUid)
        .collection('friends').doc(myUid);
    batch.set(theirFriendRef, {
      'friendUid': myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    batch.commit().then((_) {
      debugPrint('✅ Friend added: $friendUid');
    }).catchError((e) {
      debugPrint('⚠️ Friend batch commit error (local OK): $e');
    });

    // Auto-create chat room
    await ChatRepository(firestore: _firestore).getOrCreateChatRoom(myUid, friendUid);
  }

  // 3. Check if already friends (cache-first for offline support)
  Future<bool> isFriend(String friendUid) async {
    try {
      final doc = await _firestore
          .collection('users').doc(_myUid)
          .collection('friends').doc(friendUid)
          .get(const GetOptions(source: Source.cache));
      return doc.exists;
    } catch (_) {
      // Cache miss — try server
      try {
        final doc = await _firestore
            .collection('users').doc(_myUid)
            .collection('friends').doc(friendUid)
            .get(const GetOptions(source: Source.server));
        return doc.exists;
      } catch (e) {
        debugPrint('⚠️ isFriend check failed: $e');
        return false; // Default: not friend
      }
    }
  }

  // 4. Get Friends Stream (real-time)
  Stream<List<String>> getFriendUidsStream() {
    return _firestore
        .collection('users').doc(_myUid)
        .collection('friends')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // 5. Get friend profiles from UIDs
  Future<List<UserProfile>> getFriendProfiles(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    final profiles = <UserProfile>[];
    // Firestore whereIn is limited to 30 items per query
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        profiles.add(UserProfile.fromFirestore(doc));
      }
    }
    return profiles;
  }
}
