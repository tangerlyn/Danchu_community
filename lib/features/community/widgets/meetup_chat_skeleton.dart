import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/app_colors.dart';

class MeetupChatSkeleton extends StatelessWidget {
  const MeetupChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.sand.withOpacity(0.5),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: AppColors.sand.withOpacity(0.5),
        highlightColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 아이콘 자리 (48x48 rounded)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.sand.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              // 텍스트 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 채팅방 이름 + 참가자 수
                    Row(
                      children: [
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: AppColors.sand.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 12,
                          width: 16,
                          decoration: BoxDecoration(
                            color: AppColors.sand.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 마지막 메시지
                    Container(
                      height: 13,
                      width: 180,
                      decoration: BoxDecoration(
                        color: AppColors.sand.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 시간 자리
              Container(
                height: 11,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.sand.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
