import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../features/history/database_helper.dart';
import '../features/history/walk_model.dart';

class WalkPickerSheet extends StatefulWidget {
  const WalkPickerSheet({super.key});

  @override
  State<WalkPickerSheet> createState() => _WalkPickerSheetState();
}

class _WalkPickerSheetState extends State<WalkPickerSheet> {
  List<Walk> _walks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalks();
  }

  Future<void> _loadWalks() async {
    final walks = await DatabaseHelper.instance.readAllWalks();
    // 루트 포인트 있는 것만 필터링
    final filtered = walks
        .where((w) => w.decodedRoutePoints.length >= 2)
        .toList();
    // 최신순 정렬
    filtered.sort((a, b) => b.startTime.compareTo(a.startTime));
    if (mounted) setState(() {
      _walks = filtered;
      _isLoading = false;
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)}m';
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes분';
    return '${minutes ~/ 60}h ${minutes % 60}분';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '산책 기록 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBrown,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
                : _walks.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_walk, size: 48, color: AppColors.taupe),
                            SizedBox(height: 12),
                            Text('공유할 수 있는 산책 기록이 없습니다.',
                                style: TextStyle(color: AppColors.taupe, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: _walks.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.sand, height: 1),
                        itemBuilder: (context, index) {
                          final walk = _walks[index];
                          final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(walk.startTime);
                          final timeStr = DateFormat('a h:mm', 'ko_KR').format(walk.startTime);
                          final dogs = walk.dogNameList.isNotEmpty
                              ? walk.dogNameList.join(', ')
                              : null;

                          return InkWell(
                            onTap: () => Navigator.of(context).pop(walk),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.sand.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.pets, color: AppColors.deepBrown, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateStr,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.deepBrown,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$timeStr · ${_formatDistance(walk.distanceMeters)} · ${_formatDuration(walk.durationSeconds)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.taupe,
                                          ),
                                        ),
                                        if (dogs != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '🐾 $dogs',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.mocha,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.taupe, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
