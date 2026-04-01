import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// 앱 전반에서 반복되는 공통 위젯 모음.

// ---------------------------------------------------------------------------
// 1. 로딩 인디케이터
//    사용: Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
//    대체: const AppLoadingIndicator()
// ---------------------------------------------------------------------------
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.deepBrown),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 빈 화면 위젯
//    사용: Icon + SizedBox + Text 조합
//    대체: AppEmptyState(icon: ..., message: '...')
// ---------------------------------------------------------------------------
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.taupe.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.taupe,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.taupe.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. 이미지 에러 위젯
//    사용: errorBuilder: (context, error, stackTrace) => AppImageError()
// ---------------------------------------------------------------------------
class AppImageError extends StatelessWidget {
  final double height;

  const AppImageError({super.key, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.sand.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: AppColors.taupe, size: 40),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 공통 섹션 헤더
//    사용: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, ...))
//    대체: AppSectionHeader(label: '...')
// ---------------------------------------------------------------------------
class AppSectionHeader extends StatelessWidget {
  final String label;
  final double fontSize;

  const AppSectionHeader({
    super.key,
    required this.label,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.deepBrown,
      ),
    );
  }
}
