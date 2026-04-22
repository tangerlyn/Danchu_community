import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/friends_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/friend_request.dart';
import '../../services/fcm_service.dart';
import '../../domain/entities/friend_info.dart';

class FriendsController extends GetxController {
  final FriendsRepository _repository = FriendsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  String? _myUid;
  String? _myNickname;
  String? _myProfileImageUrl;

  // ── 친구 목록 ──
  final friends = <FriendInfo>[].obs;
  final isLoadingFriends = true.obs;

  // ── 받은 친구 요청 ──
  final receivedRequests = <FriendRequest>[].obs;
  final isLoadingRequests = true.obs;

  // ── 검색 ──
  final searchQuery = ''.obs;
  final searchResults = <Map<String, dynamic>>[].obs;
  final isSearching = false.obs;
  final searchController = TextEditingController();

  // ── 처리 중 상태 (버튼 중복 클릭 방지) ──
  final processingUids = <String>{}.obs;

  // 친구별 읽지 않은 직접 메시지 수
  final unreadDirectCounts = <String, int>{}.obs; // key: friendUid, value: count
  final Map<String, StreamSubscription> _unreadDirectSubscriptions = {};

  @override
  void onInit() {
    super.onInit();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadMyInfo();
    _bindStreams();
  }

  @override
  void onClose() {
    searchController.dispose();
    for (final sub in _unreadDirectSubscriptions.values) {
      sub.cancel();
    }
    _unreadDirectSubscriptions.clear();
    super.onClose();
  }

  Future<void> _loadMyInfo() async {
    if (_myUid == null) return;
    try {
      final profile = await _profileRepository.getUserProfile(_myUid!);
      _myNickname = profile?.nickname ?? '알 수 없음';
      _myProfileImageUrl = profile?.profileImageUrl ?? '';
    } catch (e) {
      debugPrint('⚠️ [FriendsController] Failed to load my info: $e');
    }
  }

  void _bindStreams() {
    if (_myUid == null) return;

    // 친구 목록 실시간 구독
    _repository.getFriendsStream(_myUid!).listen((data) {
      friends.value = data;
      isLoadingFriends.value = false;
      _updateUnreadSubscriptions(data);
    });

    // 받은 친구 요청 실시간 구독
    _repository.getReceivedRequestsStream(_myUid!).listen((data) {
      receivedRequests.value = data;
      isLoadingRequests.value = false;
    });
  }

  // ── 친구 요청 보내기 ──
  Future<void> sendFriendRequest(String targetUid) async {
    if (_myUid == null || targetUid == _myUid) return;
    if (processingUids.contains(targetUid)) return;

    processingUids.add(targetUid);
    try {
      await _repository.sendFriendRequest(
        fromUid: _myUid!,
        toUid: targetUid,
        fromNickname: _myNickname ?? '알 수 없음',
        fromProfileImageUrl: _myProfileImageUrl ?? '',
      );
      Get.snackbar('친구 요청', '친구 요청을 보냈습니다 🐾',
          snackPosition: SnackPosition.BOTTOM);

      // 상대방에게 알림 전송
      FcmService.sendFriendRequestNotification(
        toUid: targetUid,
        fromNickname: _myNickname ?? '알 수 없음',
      );
    } catch (e) {
      debugPrint('⚠️ [FriendsController] sendFriendRequest error: $e');
      Get.snackbar('잠깐!', '친구 요청에 실패했어요. 다시 시도해주세요 🐾');
    } finally {
      processingUids.remove(targetUid);
    }
  }

  // ── 친구 요청 취소 ──
  Future<void> cancelFriendRequest(String targetUid) async {
    if (_myUid == null) return;
    if (processingUids.contains(targetUid)) return;

    processingUids.add(targetUid);
    try {
      await _repository.cancelFriendRequest(
        fromUid: _myUid!,
        toUid: targetUid,
      );
      Get.snackbar('취소', '친구 요청을 취소했습니다.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('⚠️ [FriendsController] cancelFriendRequest error: $e');
      Get.snackbar('잠깐!', '요청 취소에 실패했어요 🐾');
    } finally {
      processingUids.remove(targetUid);
    }
  }

  // ── 친구 요청 수락 ──
  Future<void> acceptFriendRequest(FriendRequest request) async {
    if (_myUid == null) return;
    if (processingUids.contains(request.fromUid)) return;

    processingUids.add(request.fromUid);
    try {
      // 상대방 프로필 정보 가져오기
      final friendProfile =
          await _profileRepository.getUserProfile(request.fromUid);

      await _repository.acceptFriendRequest(
        requestId: request.id,
        fromUid: request.fromUid,
        toUid: _myUid!,
        myNickname: _myNickname ?? '알 수 없음',
        myProfileImageUrl: _myProfileImageUrl ?? '',
        friendNickname: friendProfile?.nickname ?? request.fromNickname,
        friendProfileImageUrl:
            friendProfile?.profileImageUrl ?? request.fromProfileImageUrl,
      );

      // 수락 성공 → 로컬 목록에서 즉시 제거 (stream 업데이트 기다리지 않음)
      receivedRequests.removeWhere((r) => r.id == request.id);

      Get.snackbar('친구 추가 완료', '${request.fromNickname}님과 친구가 되었습니다! 🐾',
          snackPosition: SnackPosition.BOTTOM);

      // 요청 보낸 사람에게 수락 알림
      FcmService.sendFriendAcceptedNotification(
        toUid: request.fromUid,
        fromNickname: _myNickname ?? '알 수 없음',
      );
    } catch (e) {
      debugPrint('⚠️ [FriendsController] acceptFriendRequest error: $e');
      Get.snackbar('잠깐!', '친구 수락에 실패했어요 🐾');
    } finally {
      processingUids.remove(request.fromUid);
    }
  }

  // ── 친구 요청 거절 ──
  Future<void> rejectFriendRequest(FriendRequest request) async {
    if (processingUids.contains(request.fromUid)) return;

    processingUids.add(request.fromUid);
    try {
      await _repository.rejectFriendRequest(request.id);
      // 거절 성공 → 로컬 목록에서 즉시 제거
      receivedRequests.removeWhere((r) => r.id == request.id);
    } catch (e) {
      debugPrint('⚠️ [FriendsController] rejectFriendRequest error: $e');
      Get.snackbar('잠깐!', '거절에 실패했어요 🐾');
    } finally {
      processingUids.remove(request.fromUid);
    }
  }

  // ── 친구 삭제 ──
  Future<void> removeFriend(FriendInfo friend) async {
    if (_myUid == null) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('친구 삭제',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${friend.nickname}님을 친구 목록에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.removeFriend(
        myUid: _myUid!,
        friendUid: friend.uid,
      );
      Get.snackbar('삭제 완료', '${friend.nickname}님을 친구 목록에서 삭제했습니다.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('⚠️ [FriendsController] removeFriend error: $e');
      Get.snackbar('잠깐!', '친구 삭제에 실패했어요 🐾');
    }
  }

  // ── 닉네임 검색 ──
  Future<void> searchUsers(String query) async {
    final trimmed = query.trim();
    searchQuery.value = trimmed;

    if (trimmed.isEmpty) {
      searchResults.clear();
      return;
    }

    isSearching.value = true;
    try {
      final results = await _repository.searchUsersByNickname(trimmed, _myUid ?? '');
      searchResults.value = results;
    } catch (e) {
      debugPrint('⚠️ [FriendsController] searchUsers error: $e');
    } finally {
      isSearching.value = false;
    }
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
    searchResults.clear();
  }

  // ── 친구 상태 확인 (외부에서 호출용) ──
  Future<String> getFriendStatus(String targetUid) async {
    if (_myUid == null) return 'none';
    return _repository.getFriendStatus(
      myUid: _myUid!,
      targetUid: targetUid,
    );
  }

  // ── chatId 가져오기 ──
  String getChatId(String targetUid) {
    return FriendsRepository.getChatId(_myUid ?? '', targetUid);
  }

  void _updateUnreadSubscriptions(List<FriendInfo> friendList) {
    if (_myUid == null) return;
    // 친구 목록 변경 시 구독 업데이트
    final currentFriendUids = friendList.map((f) => f.uid).toSet();

    // 친구 삭제된 경우 구독 취소
    final removedUids = _unreadDirectSubscriptions.keys
        .where((uid) => !currentFriendUids.contains(uid))
        .toList();
    for (final uid in removedUids) {
      _unreadDirectSubscriptions[uid]?.cancel();
      _unreadDirectSubscriptions.remove(uid);
      unreadDirectCounts.remove(uid);
    }

    // 새 친구 구독 추가
    for (final friend in friendList) {
      if (_unreadDirectSubscriptions.containsKey(friend.uid)) continue;
      final chatId = FriendsRepository.getChatId(_myUid!, friend.uid);
      // joinedAt 먼저 가져온 후 구독
      _repository.getFriendJoinedAt(
        myUid: _myUid!,
        friendUid: friend.uid,
      ).then((joinedAt) {
        _unreadDirectSubscriptions[friend.uid] = _repository
            .getUnreadDirectMessageCount(
              chatId: chatId,
              myUid: _myUid!,
              joinedAt: joinedAt,
            )
            .listen((count) {
          unreadDirectCounts[friend.uid] = count;
        });
      });
    }
  }

  // ── 읽지 않은 요청 수 ──
  int get unreadRequestCount => receivedRequests.length;

  String? get myUid => _myUid;
  String? get myNickname => _myNickname;
}
