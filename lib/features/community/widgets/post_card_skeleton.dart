import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/app_colors.dart';

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.sand.withOpacity(0.5),
      highlightColor: AppColors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Container(
                  height: 15,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                // 본문 첫째 줄
                Container(
                  height: 13,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 5),
                // 본문 둘째 줄
                Container(
                  height: 13,
                  width: MediaQuery.of(context).size.width * 0.45,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                // 푸터
                Container(
                  height: 11,
                  width: MediaQuery.of(context).size.width * 0.35,
                  decoration: BoxDecoration(
                    color: AppColors.sand.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 썸네일 자리
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
