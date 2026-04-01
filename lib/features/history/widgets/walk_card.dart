import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../walk_model.dart';

class WalkCard extends StatelessWidget {
  final Walk walk;
  final Map<String, Color> dogColors;
  final VoidCallback onTap;

  const WalkCard({
    super.key,
    required this.walk,
    required this.dogColors,
    required this.onTap,
  });

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}min";
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return "${meters.toStringAsFixed(0)}m";
    return "${(meters / 1000).toStringAsFixed(2)}km";
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = walk.decodedRoutePoints.length >= 2;
    final dogs = walk.dogNameList;

    return Card(
      elevation: 0,
      color: const Color(0xFFF8F5F1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.sand, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.deepBrown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pets, color: AppColors.deepBrown, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('a h:mm', 'ko').format(walk.startTime),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 14, color: AppColors.taupe),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(walk.durationSeconds),
                          style: TextStyle(fontSize: 13, color: AppColors.latte),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.straighten,
                            size: 14, color: AppColors.taupe),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(walk.distanceMeters),
                          style: TextStyle(fontSize: 13, color: AppColors.latte),
                        ),
                      ],
                    ),
                    if (dogs.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: dogs.map((name) {
                          final color = dogColors[name] ?? AppColors.taupe;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              name,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasRoute)
                Icon(Icons.route, size: 18, color: AppColors.taupe),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}
