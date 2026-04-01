import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:get/get.dart';
import '../../data/models/user_profile.dart';
import 'friend_controller.dart';
import 'mung_card_popup.dart';

class FriendListPage extends StatelessWidget {
  const FriendListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FriendController());
    final searchTextController = TextEditingController();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F3),
      appBar: AppBar(
        title: const Text(
          "친구 목록",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.deepBrown,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.deepBrown),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: searchTextController,
              onChanged: controller.onSearchChanged,
              decoration: InputDecoration(
                hintText: "닉네임 또는 강아지 이름으로 검색",
                hintStyle: TextStyle(color: AppColors.taupe, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.taupe),
                suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          searchTextController.clear();
                          controller.onSearchChanged('');
                        },
                      )
                    : const SizedBox.shrink()),
                filled: true,
                fillColor: const Color(0xFFF5F3EF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Divider
          Container(height: 1, color: AppColors.sand.withOpacity(0.5)),

          // Content
          Expanded(
            child: Obx(() {
              // Show search results if searching
              if (controller.isSearching.value) {
                return _buildSearchResults(controller);
              }
              // Show friends list
              return _buildFriendsList(controller);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(FriendController controller) {
    if (controller.isLoading.value) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5D4037)),
      );
    }

    if (controller.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.sand),
            const SizedBox(height: 12),
            Text(
              "검색 결과가 없어요",
              style: TextStyle(
                color: AppColors.taupe,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: controller.searchResults.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 76,
        color: AppColors.sand.withOpacity(0.5),
      ),
      itemBuilder: (context, index) {
        final profile = controller.searchResults[index];
        return _buildSearchResultItem(context, controller, profile);
      },
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    FriendController controller,
    UserProfile profile,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.sand,
        backgroundImage: profile.profileImageUrl.isNotEmpty
            ? CachedNetworkImageProvider(profile.profileImageUrl)
            : null,
        child: profile.profileImageUrl.isEmpty
            ? const Icon(Icons.pets, color: AppColors.deepBrown, size: 22)
            : null,
      ),
      title: Text(
        profile.dogName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.deepBrown,
        ),
      ),
      subtitle: Text(
        profile.nickname,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.latte,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.taupe,
        size: 20,
      ),
      onTap: () async {
        // Check if already friend
        final alreadyFriend = await controller.isFriend(profile.uid);
        
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => MungCardPopup(
            profile: profile,
            isAlreadyFriend: alreadyFriend,
            onExchange: () async {
              await controller.addFriend(profile.uid);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendsList(FriendController controller) {
    if (controller.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppColors.sand),
            const SizedBox(height: 16),
            Text(
              "아직 친구가 없어요",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.taupe,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "위 검색창에서 친구를 찾아보세요! 🐾",
              style: TextStyle(
                fontSize: 13,
                color: AppColors.taupe,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "내 친구 ${controller.friends.length}명",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.latte,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: controller.friends.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 76,
              color: AppColors.sand.withOpacity(0.5),
            ),
            itemBuilder: (context, index) {
              final friend = controller.friends[index];
              return _buildFriendItem(controller, friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendItem(FriendController controller, UserProfile friend) {
    return Container(
      color: AppColors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.sand,
          backgroundImage: friend.profileImageUrl.isNotEmpty
              ? CachedNetworkImageProvider(friend.profileImageUrl)
              : null,
          child: friend.profileImageUrl.isEmpty
              ? const Icon(Icons.pets, color: AppColors.deepBrown, size: 22)
              : null,
        ),
        title: Text(
          friend.dogName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.deepBrown,
          ),
        ),
        subtitle: Text(
          friend.nickname,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.latte,
          ),
        ),
        trailing: SizedBox(
          width: 110,
          height: 36,
          child: ElevatedButton.icon(
            onPressed: () => controller.openChat(friend.uid, friend.dogName),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text(
              "채팅하기",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
