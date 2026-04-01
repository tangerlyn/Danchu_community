import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/app_colors.dart';
import '../profile_controller.dart';
import '../../history/database_helper.dart';
import '../detailed_stats_page.dart';

/// Live activity stats widget that refreshes on mount.
class LiveStatsWidget extends StatefulWidget {
  const LiveStatsWidget({super.key});

  @override
  State<LiveStatsWidget> createState() => LiveStatsWidgetState();
}

class LiveStatsWidgetState extends State<LiveStatsWidget> with WidgetsBindingObserver {
  int _weekWalks = 0;
  double _weekDistance = 0.0;
  int _weekMinutes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchStats();
    }
  }

  Future<void> refreshStats() async {
    await _fetchStats();
  }

  Future<void> _fetchStats() async {
    final walks = await DatabaseHelper.instance.readAllWalks();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeek = DateTime(weekStart.year, weekStart.month, weekStart.day);

    int count = 0;
    double distance = 0.0;
    int minutes = 0;
    for (final walk in walks) {
      if (walk.startTime.isAfter(startOfWeek)) {
        count++;
        distance += walk.distanceMeters / 1000.0;
        minutes += walk.durationSeconds ~/ 60;
      }
    }

    if (mounted) {
      setState(() {
        _weekWalks = count;
        _weekDistance = distance;
        _weekMinutes = minutes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '활동 통계',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Get.to(() => const DetailedStatsPage()),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '더보기',
                      style: TextStyle(fontSize: 13, color: AppColors.taupe, fontWeight: FontWeight.w500),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.taupe),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _statTile(Icons.pets, '이번 주 산책', '$_weekWalks회')),
                const SizedBox(width: 8),
                Expanded(child: _statTile(Icons.directions_run, '산책 거리', '${_weekDistance.toStringAsFixed(1)}km')),
                const SizedBox(width: 8),
                Expanded(child: _statTile(Icons.timer, '산책 시간', '$_weekMinutes분')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: AppColors.deepBrown),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.taupe)),
          ),
        ],
      ),
    );
  }
}
