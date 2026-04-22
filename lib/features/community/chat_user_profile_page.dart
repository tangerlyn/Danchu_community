import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/profile_repository.dart';
import 'package:get/get.dart';
import '../profile/widgets/mung_card_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/community_post.dart';
import 'post_detail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../friends/friends_controller.dart';
import '../friends/friends_page.dart';
class ChatUserProfilePage extends StatefulWidget {
  final String uid;

  const ChatUserProfilePage({super.key, required this.uid});

  @override
  State<ChatUserProfilePage> createState() => _ChatUserProfilePageState();
}

class _ChatUserProfilePageState extends State<ChatUserProfilePage> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentDogIndex = 0;
  
  UserProfile? _profile;
  bool _isLoading = true;

  int _selectedTabIndex = 0; // 0: 단카, 1: 게시글
  List<CommunityPost> _userPosts = [];
  bool _isPostsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileRepository.getUserProfile(widget.uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
    // 게시글 로드 (프로필 로드 후 백그라운드로)
    _loadUserPosts();
  }

  Future<void> _loadUserPosts() async {
    if (mounted) setState(() => _isPostsLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('community_posts')
          .where('authorUid', isEqualTo: widget.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final posts = snapshot.docs
          .map((doc) => CommunityPost.fromJson(doc.data(), doc.id))
          .toList();

      if (mounted) setState(() => _userPosts = posts);
    } catch (e) {
      debugPrint('⚠️ Failed to load user posts: $e');
    } finally {
      if (mounted) setState(() => _isPostsLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.deepBrown, size: 20),
          onPressed: () => Get.back(),
        ),

        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
    }

    if (_profile == null) {
      return const Center(
        child: Text('사용자 정보를 불러올 수 없습니다.', style: TextStyle(color: AppColors.taupe)),
      );
    }

    final profile = _profile!;
    final dogs = profile.effectiveDogs;

    return Column(
      children: [
        // ── 프로필 헤더 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sand, width: 2),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.sand,
                  backgroundImage: profile.profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(profile.profileImageUrl)
                      : null,
                  child: profile.profileImageUrl.isEmpty
                      ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity))
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.nickname,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.deepBrown,
                            ),
                          ),
                        ),
                        // 본인 프로필이면 버튼 숨김
                        if (widget.uid != FirebaseAuth.instance.currentUser?.uid)
                          _ProfileFriendButton(targetUid: widget.uid),
                      ],
                    ),
                    if (profile.intro.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        profile.intro,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mocha,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── 탭 바 ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.sand.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTabButton('단카', 0, null),
              _buildTabButton('게시글', 1, _userPosts.length),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 탭 콘텐츠 ──
        Expanded(
          child: _selectedTabIndex == 0
              ? _buildDogTab(profile, dogs)
              : _buildPostsTab(),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, int? count) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                : [],
          ),
          child: Center(
            child: Text(
              count != null ? '$label  $count' : label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.deepBrown : AppColors.taupe,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDogTab(dynamic profile, List<dynamic> dogs) {
    if (dogs.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(vertical: 48),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 40, color: AppColors.sand),
              SizedBox(height: 12),
              Text('등록된 단카가 없습니다.', style: TextStyle(color: AppColors.taupe, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (dogs.length == 1) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MungCardWidget(dog: dogs.first, profile: profile),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: dogs.length,
            onPageChanged: (index) => setState(() => _currentDogIndex = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: MungCardWidget(dog: dogs[index], profile: profile),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dogs.length, (index) {
              final isActive = _currentDogIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.deepBrown : AppColors.sand,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsTab() {
    if (_isPostsLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.deepBrown));
    }

    if (_userPosts.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(vertical: 48),
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 40, color: AppColors.sand),
              SizedBox(height: 12),
              Text('작성한 게시글이 없습니다.', style: TextStyle(color: AppColors.taupe, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _userPosts.length,
      separatorBuilder: (_, __) => const Divider(color: AppColors.sand, height: 1),
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return InkWell(
          onTap: () => Get.to(() => PostDetailPage(post: post)),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 태그
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.sand.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${post.mainCategory} · ${post.subCategoryTag}',
                          style: const TextStyle(fontSize: 11, color: AppColors.deepBrown, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 제목
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepBrown,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 날짜 + 좋아요 + 댓글
                      Row(
                        children: [
                          Text(
                            DateFormat('yyyy.MM.dd').format(post.createdAt),
                            style: const TextStyle(fontSize: 12, color: AppColors.taupe),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.favorite_border, size: 12, color: AppColors.taupe),
                          const SizedBox(width: 2),
                          Text('${post.likeCount}', style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
                          const SizedBox(width: 8),
                          const Icon(Icons.chat_bubble_outline, size: 12, color: AppColors.taupe),
                          const SizedBox(width: 2),
                          Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
                        ],
                      ),
                    ],
                  ),
                ),
                // 게시글 이미지 썸네일 (있으면)
                if (post.imageUrls.isNotEmpty || post.videoThumbnailUrl != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: post.videoThumbnailUrl ?? post.imageUrls.first,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 64, height: 64,
                        color: AppColors.sand,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileFriendButton extends StatefulWidget {
  final String targetUid;
  const _ProfileFriendButton({required this.targetUid});

  @override
  State<_ProfileFriendButton> createState() => _ProfileFriendButtonState();
}

class _ProfileFriendButtonState extends State<_ProfileFriendButton> {
  String _status = 'loading';
  late FriendsController _controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<FriendsController>()) {
      Get.put(FriendsController());
    }
    _controller = Get.find<FriendsController>();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await _controller.getFriendStatus(widget.targetUid);
    debugPrint('🔍 [FriendButton] targetUid: ${widget.targetUid}, status: $status');
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'loading') {
      return const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.deepBrown),
      );
    }

    String label;
    Color bgColor;
    Color textColor;
    VoidCallback? onTap;

    switch (_status) {
      case 'friend':
        label = '친구';
        bgColor = AppColors.sand.withOpacity(0.5);
        textColor = AppColors.taupe;
        onTap = null;
        break;
      case 'sent':
        label = '요청 취소';
        bgColor = AppColors.sand.withOpacity(0.4);
        textColor = AppColors.taupe;
        onTap = () async {
          await _controller.cancelFriendRequest(widget.targetUid);
          _loadStatus();
        };
        break;
      case 'received':
        label = '수락하기';
        bgColor = AppColors.deepBrown;
        textColor = Colors.white;
        onTap = () async {
          final request = _controller.receivedRequests
              .firstWhereOrNull((r) => r.fromUid == widget.targetUid);
          if (request != null) {
            await _controller.acceptFriendRequest(request);
            _loadStatus();
          }
        };
        break;
      default: // 'none'
        label = '친구 추가';
        bgColor = AppColors.deepBrown;
        textColor = Colors.white;
        onTap = () async {
          await _controller.sendFriendRequest(widget.targetUid);
          _loadStatus();
        };
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
