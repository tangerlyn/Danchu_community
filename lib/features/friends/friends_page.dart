import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/friend_info.dart';
import '../../domain/entities/friend_request.dart';
import 'friends_controller.dart';
import '../community/chat_user_profile_page.dart';
import 'direct_chat_page.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FriendsController());

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '친구',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBrown,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── 검색창 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.searchUsers,
              style: const TextStyle(fontSize: 14, color: AppColors.deepBrown),
              decoration: InputDecoration(
                hintText: '닉네임으로 친구 검색',
                hintStyle:
                    const TextStyle(color: AppColors.taupe, fontSize: 14),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.taupe, size: 20),
                suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.taupe, size: 18),
                        onPressed: controller.clearSearch,
                      )
                    : const SizedBox.shrink()),
                filled: true,
                fillColor: AppColors.sand.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── 콘텐츠 ──
          Expanded(
            child: Obx(() {
              // 검색 중이면 검색 결과
              if (controller.searchQuery.value.isNotEmpty) {
                return _buildSearchResults(controller);
              }
              // 검색 아니면 친구 목록 + 받은 요청
              return _buildMainContent(controller);
            }),
          ),
        ],
      ),
    );
  }

  // ── 메인 콘텐츠 (친구 목록 + 받은 요청) ──
  Widget _buildMainContent(FriendsController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 받은 친구 요청 섹션
          Obx(() {
            if (controller.receivedRequests.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '받은 친구 요청',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBrown,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.deepBrown,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${controller.receivedRequests.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...controller.receivedRequests
                    .map((req) => _buildRequestItem(req, controller)),
                const SizedBox(height: 24),
                const Divider(color: AppColors.sand),
                const SizedBox(height: 16),
              ],
            );
          }),

          // 친구 목록 섹션
          Obx(() {
            return Row(
              children: [
                Text(
                  '친구',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.friends.length}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.taupe,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),

          Obx(() {
            if (controller.isLoadingFriends.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.deepBrown),
                ),
              );
            }

            if (controller.friends.isEmpty) {
              return _buildEmptyFriends();
            }

            return Column(
              children: controller.friends
                  .map((f) => _buildFriendItem(f, controller))
                  .toList(),
            );
          }),
        ],
      ),
    );
  }

  // ── 친구 요청 아이템 ──
  Widget _buildRequestItem(
      FriendRequest request, FriendsController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 사진
          GestureDetector(
            onTap: () =>
                Get.to(() => ChatUserProfilePage(uid: request.fromUid)),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.sand,
              backgroundImage:
                  request.fromProfileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(request.fromProfileImageUrl)
                      : null,
              child: request.fromProfileImageUrl.isEmpty
                  ? ClipOval(
                      child: Image.asset('assets/icon/app_icon3.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity))
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // 닉네임
          Expanded(
            child: Text(
              request.fromNickname,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.deepBrown,
              ),
            ),
          ),
          // 수락/거절 버튼
          Obx(() {
            final isProcessing =
                controller.processingUids.contains(request.fromUid);
            if (isProcessing) {
              return const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepBrown),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 거절
                GestureDetector(
                  onTap: () => controller.rejectFriendRequest(request),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.sand.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '거절',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.taupe,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 수락
                GestureDetector(
                  onTap: () => controller.acceptFriendRequest(request),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.deepBrown,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '수락',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── 친구 아이템 ──
  Widget _buildFriendItem(FriendInfo friend, FriendsController controller) {
    return InkWell(
      onTap: () => Get.to(() => ChatUserProfilePage(uid: friend.uid)),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.sand,
              backgroundImage: friend.profileImageUrl.isNotEmpty
                  ? CachedNetworkImageProvider(friend.profileImageUrl)
                  : null,
              child: friend.profileImageUrl.isEmpty
                  ? ClipOval(
                      child: Image.asset('assets/icon/app_icon3.png',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                friend.nickname,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepBrown,
                ),
              ),
            ),
            // 메시지 버튼
            GestureDetector(
              onTap: () {
                final chatId = controller.getChatId(friend.uid);
                Get.to(() => DirectChatPage(
                      chatId: chatId,
                      friendUid: friend.uid,
                      friendNickname: friend.nickname,
                      friendProfileImageUrl: friend.profileImageUrl,
                    ));
              },
              child: Obx(() {
                final unread = controller.unreadDirectCounts[friend.uid] ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sand.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.deepBrown),
                          SizedBox(width: 4),
                          Text('메시지', style: TextStyle(fontSize: 13, color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
            const SizedBox(width: 8),
            // 더보기 (친구 삭제)
            GestureDetector(
              onTap: () => controller.removeFriend(friend),
              child: const Icon(Icons.more_horiz,
                  color: AppColors.taupe, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ── 검색 결과 ──
  Widget _buildSearchResults(FriendsController controller) {
    return Obx(() {
      if (controller.isSearching.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.deepBrown),
        );
      }

      if (controller.searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off,
                  size: 48, color: AppColors.taupe.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                '"${controller.searchQuery.value}"에 대한 결과가 없습니다.',
                style:
                    const TextStyle(color: AppColors.taupe, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: controller.searchResults.length,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.sand, height: 1),
        itemBuilder: (context, index) {
          final user = controller.searchResults[index];
          final uid = user['uid'] as String;
          final nickname = user['nickname'] as String? ?? '알 수 없음';
          final profileImageUrl = user['profileImageUrl'] as String? ?? '';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      Get.to(() => ChatUserProfilePage(uid: uid)),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.sand,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profileImageUrl)
                        : null,
                    child: profileImageUrl.isEmpty
                        ? ClipOval(
                            child: Image.asset('assets/icon/app_icon3.png',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity))
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    nickname,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepBrown,
                    ),
                  ),
                ),
                // 친구 상태에 따른 버튼
                _FriendStatusButton(
                  targetUid: uid,
                  controller: controller,
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // ── 빈 친구 목록 ──
  Widget _buildEmptyFriends() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.people_outline,
                size: 56, color: AppColors.taupe.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              '아직 친구가 없어요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.taupe,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '닉네임으로 검색해서 친구를 추가해보세요!',
              style: TextStyle(fontSize: 13, color: AppColors.taupe),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 친구 상태 버튼 (검색 결과에서 사용) ──
class _FriendStatusButton extends StatefulWidget {
  final String targetUid;
  final FriendsController controller;

  const _FriendStatusButton({
    required this.targetUid,
    required this.controller,
  });

  @override
  State<_FriendStatusButton> createState() => _FriendStatusButtonState();
}

class _FriendStatusButtonState extends State<_FriendStatusButton> {
  String _status = 'loading';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status =
        await widget.controller.getFriendStatus(widget.targetUid);
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'loading') {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.deepBrown),
      );
    }

    if (_status == 'friend') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.sand.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '친구',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.taupe,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_status == 'sent') {
      return GestureDetector(
        onTap: () async {
          await widget.controller.cancelFriendRequest(widget.targetUid);
          _loadStatus();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.sand.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '요청 취소',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.taupe,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_status == 'received') {
      return GestureDetector(
        onTap: () async {
          // 받은 요청 찾아서 수락
          final request = widget.controller.receivedRequests
              .firstWhereOrNull((r) => r.fromUid == widget.targetUid);
          if (request != null) {
            await widget.controller.acceptFriendRequest(request);
            _loadStatus();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.deepBrown,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '수락하기',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // 'none' — 친구 추가 버튼
    return GestureDetector(
      onTap: () async {
        await widget.controller.sendFriendRequest(widget.targetUid);
        _loadStatus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.deepBrown,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '친구 추가',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

