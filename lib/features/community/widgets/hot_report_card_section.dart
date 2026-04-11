import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../../../core/date_utils.dart';
import '../../../domain/entities/community_post.dart';
import '../post_detail_page.dart';
import '../community_controller.dart';
import '../../auth/auth_controller.dart';

/// Horizontal scrollable hot posts section with PageView + dot indicators.
class HotPostsSection extends StatefulWidget {
  final String mainCategory;
  const HotPostsSection({super.key, required this.mainCategory});

  @override
  State<HotPostsSection> createState() => _HotPostsSectionState();
}

class _HotPostsSectionState extends State<HotPostsSection> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CommunityController>();

    return Obx(() {
      final allHotPosts = controller.hotPostsMap[widget.mainCategory]?.value ?? [];
      final blockedUsers = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().blockedUsers
          : <String>[];
      final hotPosts = allHotPosts.where((p) => !blockedUsers.contains(p.authorUid)).toList();
      if (hotPosts.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '인기 ${widget.mainCategory}글',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBrown,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Card PageView
          SizedBox(
            height: 155, // Increased slightly for footer
            child: PageView.builder(
              controller: _pageController,
              itemCount: hotPosts.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return _HotPostCard(post: hotPosts[index]);
              },
            ),
          ),

          // Dot Indicators
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              hotPosts.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentPage == index
                      ? AppColors.deepBrown
                      : AppColors.sand,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(height: 24, color: AppColors.sand, thickness: 1, indent: 16, endIndent: 16),
        ],
      );
    });
  }
}

class _HotPostCard extends StatelessWidget {
  final CommunityPost post;
  const _HotPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => PostDetailPage(post: post)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sand.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: AppColors.mocha.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subcategory Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.deepBrown.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                post.subCategoryTag,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.deepBrown,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Content preview
            Text(
              post.content,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.latte.withOpacity(0.9),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const Spacer(),

            // Engagement stats footer
            Row(
              children: [
                Text(
                  formatRelativeTime(post.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.taupe),
                ),
                const Spacer(),
                const Icon(Icons.favorite_border, size: 14, color: AppColors.taupe),
                const SizedBox(width: 3),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mocha),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.taupe),
                const SizedBox(width: 3),
                Text(
                  '${post.commentCount}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mocha),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.visibility_outlined, size: 14, color: AppColors.taupe),
                const SizedBox(width: 3),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mocha),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
