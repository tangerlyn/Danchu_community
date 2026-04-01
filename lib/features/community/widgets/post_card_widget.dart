import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../../../core/date_utils.dart';
import '../../../core/text_highlight.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../domain/entities/community_post.dart';
import '../post_detail_page.dart';
import '../community_controller.dart';

/// Reusable post card used in both community list and search results.
class PostCardWidget extends StatelessWidget {
  final CommunityPost post;
  final bool isGlobalView;
  final String? highlightQuery;

  const PostCardWidget({
    super.key,
    required this.post,
    this.isGlobalView = true,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Get.to(() => PostDetailPage(post: post)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildBody(),
                const SizedBox(height: 12),
                _buildFooter(),
              ],
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrls.first,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Shimmer.fromColors(
                    baseColor: AppColors.sand.withOpacity(0.5),
                    highlightColor: AppColors.white,
                    child: Container(
                      width: 72,
                      height: 72,
                      color: AppColors.sand.withOpacity(0.3),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: AppColors.taupe, size: 24),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final displayMainCategory = post.mainCategory == '장소' ? '자유' : post.mainCategory;
    final categoryLabel = isGlobalView
        ? '$displayMainCategory > ${post.subCategoryTag}'
        : post.subCategoryTag;

    return Row(
      children: [
        if (displayMainCategory != '자유' && displayMainCategory != '모임') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              categoryLabel,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.deepBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (post.mainCategory == '모임')
          Obx(() {
            final controller = Get.isRegistered<CommunityController>() 
                ? Get.find<CommunityController>() 
                : null;
            final isParticipating = controller?.myMeetupPostIds.contains(post.id) == true;
            
            if (isParticipating) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.deepBrown,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('참가', style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.white,
                )),
              );
            }

            final isFull = post.meetupCapacity != null && post.currentParticipantCount >= post.meetupCapacity!;
            if (isFull) {
              return Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.taupe,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('마감', style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.bold, 
                  color: AppColors.white,
                )),
              );
            }

            return const SizedBox.shrink();
          }),
        Expanded(
          child: highlightQuery != null
              ? highlightText(
                  post.title,
                  highlightQuery!,
                  const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBrown,
                  ),
                )
              : Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBrown,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    Widget contentText;
    if (highlightQuery != null) {
      contentText = buildContextSnippet(post.content, highlightQuery!);
    } else {
      contentText = Text(
        post.content,
        style: const TextStyle(fontSize: 14, color: AppColors.latte),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final hasLocation = post.meetupLocation != null && post.meetupLocation!.isNotEmpty;
    final hasCapacity = post.meetupCapacity != null;
    final hasDate = post.meetupDate != null;

    if (post.mainCategory == '모임' && (hasLocation || hasCapacity || hasDate)) {
      final dateStr = hasDate ? DateFormat('M월 d일(E)', 'ko_KR').format(post.meetupDate!) : '';
      final locStr = post.meetupLocation ?? "미정";
      final capStr = '${post.currentParticipantCount}/${post.meetupCapacity ?? "?"}명';
      
      final parts = <String>[];
      if (dateStr.isNotEmpty) parts.add(dateStr);
      parts.add(locStr);
      parts.add(capStr);
      final infoStr = parts.join(' · ');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          contentText,
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(hasDate ? Icons.calendar_today : Icons.location_on, size: 14, color: AppColors.deepBrown),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    infoStr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return contentText;
  }

  Widget _buildFooter() {
    final editLabel = post.isEdited ? ' · 수정됨' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            '${post.authorNickname} · ${formatRelativeTime(post.createdAt)}$editLabel',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            const Icon(Icons.favorite_border, size: 16, color: AppColors.taupe),
            const SizedBox(width: 4),
            Text('${post.likeCount}', style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
            const SizedBox(width: 12),
            const Icon(Icons.comment_outlined, size: 16, color: AppColors.taupe),
            const SizedBox(width: 4),
            Text('${post.commentCount}', style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
            const SizedBox(width: 12),
            const Icon(Icons.visibility_outlined, size: 16, color: AppColors.taupe),
            const SizedBox(width: 4),
            Text('${post.viewCount}', style: const TextStyle(fontSize: 12, color: AppColors.taupe)),
          ],
        ),
      ],
    );
  }
}
