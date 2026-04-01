import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'report_types.dart';

class ReportBottomSheet extends StatelessWidget {
  const ReportBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Report a Hazard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help keep other dogs safe!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.latte,
                ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: reportTypes.length,
            itemBuilder: (context, index) {
              final type = reportTypes[index];
              return _ReportCard(type: type);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportType type;

  const _ReportCard({required this.type});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sand.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('신고 접수: ${type.label}'),
              backgroundColor: AppColors.deepBrown,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              type.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.deepBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
