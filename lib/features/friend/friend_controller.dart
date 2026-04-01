import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_profile.dart';
import '../../domain/repositories/friend_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../chat/chat_room_page.dart';

class FriendController extends GetxController {
  final FriendRepository _friendRepo = FriendRepository();
  final ChatRepository _chatRepo = ChatRepository();

  // State
  final RxString searchQuery = ''.obs;
  final RxList<UserProfile> searchResults = <UserProfile>[].obs;
  final RxList<UserProfile> friends = <UserProfile>[].obs;
  final RxBool isSearching = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isAddingFriend = false.obs;

  Timer? _debounce;
  StreamSubscription? _friendsSub;

  @override
  void onInit() {
    super.onInit();
    _listenToFriends();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _friendsSub?.cancel();
    super.onClose();
  }

  // Listen to friends list in real-time
  void _listenToFriends() {
    _friendsSub = _friendRepo.getFriendUidsStream().listen((uids) async {
      if (uids.isEmpty) {
        friends.clear();
        return;
      }
      final profiles = await _friendRepo.getFriendProfiles(uids);
      friends.value = profiles;
    });
  }

  // Debounced search
  void onSearchChanged(String query) {
    searchQuery.value = query;
    _debounce?.cancel();
    
    if (query.trim().isEmpty) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }

    isSearching.value = true;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      isLoading.value = true;
      try {
        final results = await _friendRepo.searchUsers(query);
        searchResults.value = results;
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        isLoading.value = false;
      }
    });
  }

  // Add friend instantly
  Future<void> addFriend(String friendUid) async {
    isAddingFriend.value = true;
    try {
      await _friendRepo.addFriend(friendUid);
      
      // Remove from search results (visual feedback)
      searchResults.removeWhere((p) => p.uid == friendUid);
      
      Get.snackbar(
        "친구 추가 완료! 🐾",
        "멍카가 교환되었어요!",
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.white,
        colorText: AppColors.deepBrown,
        borderColor: AppColors.deepBrown,
        borderWidth: 1,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar("오류", "친구 추가에 실패했습니다: $e");
    } finally {
      isAddingFriend.value = false;
    }
  }

  // Check if already friend
  Future<bool> isFriend(String uid) async {
    return await _friendRepo.isFriend(uid);
  }

  // Open 1:1 chat with friend
  Future<void> openChat(String friendUid, String friendName) async {
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_1';
      final roomId = await _chatRepo.getOrCreateChatRoom(myUid, friendUid);
      
      Get.to(() => ChatRoomPage(
        roomId: roomId,
        otherUid: friendUid,
        otherName: friendName,
      ));
    } catch (e) {
      Get.snackbar("오류", "채팅방을 열 수 없습니다: $e");
    }
  }
}
