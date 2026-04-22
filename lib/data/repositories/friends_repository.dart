import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_info.dart';

class FriendsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── 친구 요청 ID 생성 규칙 ──
  // requestId = fromUid_toUid (정렬 없이 보낸 사람 기준)

  // ── chatId 생성 규칙 ──
  // 두 uid를 정렬해서 언더스코어로 연결 (중복 방지)
  static String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// 친구 요청 전송
  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
    required String fromNickname,
    required String fromProfileImageUrl,
  }) async {
    final requestId = '${fromUid}_$toUid';
    await _firestore.collection('friend_requests').doc(requestId).set({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromNickname': fromNickname,
      'fromProfileImageUrl': fromProfileImageUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 친구 요청 취소 (보낸 사람이 취소)
  Future<void> cancelFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final requestId = '${fromUid}_$toUid';
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  /// 친구 요청 수락
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
    required String myNickname,
    required String myProfileImageUrl,
    required String friendNickname,
    required String friendProfileImageUrl,
  }) async {
    final batch = _firestore.batch();

    // 1. 요청 상태 업데이트
    batch.update(
      _firestore.collection('friend_requests').doc(requestId),
      {'status': 'accepted'},
    );

    // 2. 내 친구 목록에 추가
    batch.set(
      _firestore.collection('users').doc(toUid).collection('friends').doc(fromUid),
      {
        'nickname': friendNickname,
        'profileImageUrl': friendProfileImageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );

    // 3. 상대방 친구 목록에도 추가 (양방향)
    batch.set(
      _firestore.collection('users').doc(fromUid).collection('friends').doc(toUid),
      {
        'nickname': myNickname,
        'profileImageUrl': myProfileImageUrl,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );

    // 4. 1대1 채팅방 미리 생성
    final chatId = getChatId(fromUid, toUid);
    batch.set(
      _firestore.collection('direct_chats').doc(chatId),
      {
        'participants': [fromUid, toUid],
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// 친구 요청 거절
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  /// 친구 삭제
  Future<void> removeFriend({
    required String myUid,
    required String friendUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(
      _firestore.collection('users').doc(myUid).collection('friends').doc(friendUid),
    );
    batch.delete(
      _firestore.collection('users').doc(friendUid).collection('friends').doc(myUid),
    );
    await batch.commit();
  }

  /// 내 친구 목록 스트림
  Stream<List<FriendInfo>> getFriendsStream(String myUid) {
    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendInfo.fromJson(doc.id, doc.data()))
            .toList());
  }

  /// 받은 친구 요청 스트림
  Stream<List<FriendRequest>> getReceivedRequestsStream(String myUid) {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FriendRequest.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// 보낸 친구 요청 목록 (단일 조회)
  Future<List<FriendRequest>> getSentRequests(String myUid) async {
    final snap = await _firestore
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();
    return snap.docs
        .map((doc) => FriendRequest.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// 두 사람 간의 친구 요청 상태 확인
  /// 반환값: 'none' | 'sent' | 'received' | 'friend'
  Future<String> getFriendStatus({
    required String myUid,
    required String targetUid,
  }) async {
    // 1. 이미 친구인지 확인
    try {
      final friendDoc = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(targetUid)
          .get();
      debugPrint('🔍 [getFriendStatus] friendDoc.exists: ${friendDoc.exists}');
      if (friendDoc.exists) return 'friend';
    } catch (e) {
      debugPrint('⚠️ getFriendStatus friends check error: $e');
    }

    // 2. 내가 보낸 요청 확인
    try {
      final sentSnap = await _firestore
          .collection('friend_requests')
          .where('fromUid', isEqualTo: myUid)
          .where('toUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (sentSnap.docs.isNotEmpty) return 'sent';
    } catch (e) {
      debugPrint('⚠️ getFriendStatus sent check error: $e');
    }

    // 3. 상대방이 보낸 요청 확인
    try {
      final receivedSnap = await _firestore
          .collection('friend_requests')
          .where('fromUid', isEqualTo: targetUid)
          .where('toUid', isEqualTo: myUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (receivedSnap.docs.isNotEmpty) return 'received';
    } catch (e) {
      debugPrint('⚠️ getFriendStatus received check error: $e');
    }

    return 'none';
  }

  /// 닉네임으로 유저 검색 (포함 검색)
  Future<List<Map<String, dynamic>>> searchUsersByNickname(
      String query, String myUid) async {
    if (query.trim().isEmpty) return [];

    try {
      // Firestore는 포함 검색을 지원 안 해서
      // 전체 유저에서 클라이언트 필터링 (유저가 적을 때 유효)
      // 유저가 많아지면 Algolia 같은 검색 서비스로 전환 필요
      final snap = await _firestore
          .collection('users')
          .orderBy('nickname')
          .limit(200) // 최대 200명까지만 가져옴
          .get();

      final lowerQuery = query.trim().toLowerCase();

      return snap.docs
          .where((doc) {
            final uid = doc.id;
            if (uid == myUid) return false; // 본인 제외
            final nickname =
                (doc.data()['nickname'] as String? ?? '').toLowerCase();
            return nickname.contains(lowerQuery); // 포함 검색
          })
          .map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return data;
          })
          .toList();
    } catch (e) {
      debugPrint('⚠️ searchUsersByNickname error: $e');
      return [];
    }
  }

  /// 1대1 채팅 메시지 전송
  Future<void> sendDirectMessage({
    required String chatId,
    required Map<String, dynamic> messageData,
  }) async {
    final msgRef = _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final batch = _firestore.batch();

    batch.set(msgRef, {
      ...messageData,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(
      _firestore.collection('direct_chats').doc(chatId),
      {
        'lastMessage': messageData['message'] ?? '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// 1대1 채팅 메시지 스트림
  Stream<List<Map<String, dynamic>>> getDirectMessagesStream(
    String chatId, {
    DateTime? joinedAt,
  }) {
    Query query = _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false);

    // 친구가 된 시점 이후 메시지만 보여주기
    if (joinedAt != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(joinedAt),
      );
    }

    return query.snapshots().map((snap) => snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// 읽음 처리
  Future<void> markDirectMessagesAsRead({
    required String chatId,
    required String myUid,
  }) async {
    final recentMsgs = await _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final batch = _firestore.batch();
    for (final doc in recentMsgs.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(myUid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([myUid]),
        });
      }
    }
    await batch.commit();
  }

  /// 이미지 업로드 (채팅용 - Firebase Storage)
  /// MeetupChatRepository의 uploadImage와 동일한 방식
  String getNewMessageId(String chatId) {
    return _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages')
        .doc()
        .id;
  }

  /// 1대1 채팅 읽지 않은 메시지 수 실 실시간 스트림
  Stream<int> getUnreadDirectMessageCount({
    required String chatId,
    required String myUid,
    DateTime? joinedAt,
  }) {
    Query query = _firestore
        .collection('direct_chats')
        .doc(chatId)
        .collection('messages');

    if (joinedAt != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(joinedAt),
      );
    }

    return query.snapshots().map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final senderUid = data['senderUid'] as String? ?? '';
        final readBy = List<String>.from(data['readBy'] ?? []);
        return senderUid != myUid && !readBy.contains(myUid);
      }).length;
    });
  }

  /// 현재 유저의 친구 추가 시점 가져오기
  Future<DateTime?> getFriendJoinedAt({
    required String myUid,
    required String friendUid,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(friendUid)
          .get();
      if (doc.exists) {
        final timestamp = doc.data()?['addedAt'] as Timestamp?;
        return timestamp?.toDate();
      }
    } catch (e) {
      debugPrint('⚠️ getFriendJoinedAt error: $e');
    }
    return null;
  }
}
