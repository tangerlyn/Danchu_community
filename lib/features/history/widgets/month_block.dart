import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/schedule_event.dart';
import '../walk_model.dart';

class MonthBlock extends StatelessWidget {
  final DateTime month;
  final Map<String, List<Walk>> walksByDate;
  final Map<String, Color> dogColors;
  final Map<String, List<ScheduleEvent>> schedulesByDate;
  final DateTime? selectedDate;
  final void Function(DateTime) onDayTapped;
  final void Function(DateTime) onDayLongPressed;

  const MonthBlock({
    super.key,
    required this.month,
    required this.walksByDate,
    required this.dogColors,
    required this.schedulesByDate,
    required this.selectedDate,
    required this.onDayTapped,
    required this.onDayLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;

    // Compute monthly averages
    final monthStats = _computeMonthlyAverages(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              DateFormat('yyyy년 M월', 'ko').format(month),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCurrentMonth ? AppColors.deepBrown : AppColors.deepBrown,
              ),
            ),
          ),
          // Monthly average stats row
          if (monthStats != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Text(
                    '월 평균 ',
                    style: TextStyle(fontSize: 16, color: AppColors.latte,fontWeight: FontWeight.w500)
                  ),
                  _miniStat(Icons.pets, '${monthStats.$1}회'),
                  const SizedBox(width: 12),
                  _miniStat(Icons.directions_run, '${monthStats.$2}km'),
                  const SizedBox(width: 12),
                  _miniStat(Icons.timer, '${monthStats.$3}분'),
                ],
              ),
            )
          else
            const SizedBox(height: 8),
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: d == '일'
                                ? AppColors.deepBrown
                                : d == '토'
                                    ? AppColors.taupe
                                    : AppColors.taupe,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          _buildDayGrid(now, daysInMonth, firstWeekday),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.taupe),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.latte,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Returns (avgWalks, avgDistanceKm, avgMinutes) or null if no walks.
  (String, String, String)? _computeMonthlyAverages(DateTime now) {
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final lastDay = isCurrentMonth ? now.day : daysInMonth;

    int daysWithWalks = 0;
    int totalWalkCount = 0;
    double totalDistanceM = 0;
    int totalDurationSec = 0;

    for (int d = 1; d <= lastDay; d++) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      final dayWalks = walksByDate[key];
      if (dayWalks != null && dayWalks.isNotEmpty) {
        daysWithWalks++;
        totalWalkCount += dayWalks.length;
        for (final w in dayWalks) {
          totalDistanceM += w.distanceMeters;
          totalDurationSec += w.durationSeconds;
        }
      }
    }

    if (daysWithWalks == 0 || lastDay == 0) return null;

    final avgWalks = (totalWalkCount / lastDay).toStringAsFixed(1);
    final avgDistKm = (totalDistanceM / lastDay / 1000).toStringAsFixed(1);
    final avgMinutes = (totalDurationSec / lastDay / 60).round().toString();

    return (avgWalks, avgDistKm, avgMinutes);
  }

  Widget _buildDayGrid(DateTime now, int daysInMonth, int firstWeekday) {
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - firstWeekday + 1;

            if (cellIndex < firstWeekday || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 48));
            }

            final date = DateTime(month.year, month.month, dayNum);
            final dateKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final walks = walksByDate[dateKey] ?? [];
            final hasWalks = walks.isNotEmpty;
            final schedules = schedulesByDate[dateKey] ?? [];
            final hasSchedules = schedules.isNotEmpty;

            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

            final isSelected = selectedDate != null &&
                date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;

            final dayDogNames = <String>{};
            for (final w in walks) {
              dayDogNames.addAll(w.dogNameList);
            }

            // Base styling: Only highlight Today or Selected with a circle
            Color? bgColor;
            Color textColor = AppColors.deepBrown;
            if (isToday || isSelected) {
              bgColor = AppColors.deepBrown.withValues(alpha: 0.8);
              textColor = AppColors.white;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayTapped(date),
                onLongPress: () => onDayLongPressed(date),
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Today / Selected Highlight
                      if (isToday || isSelected)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                        ),

                      // 2. Walk Marker: Icon for all states
                      if (hasWalks)
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.pets,
                              size: 36,
                              color: (isToday || isSelected)
                                  ? AppColors.sand
                                  : AppColors.deepBrown.withOpacity(0.3),
                            ),
                          ),
                        ),
                      
                      // 3. Day Number
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday || isSelected ? FontWeight.bold : (hasWalks || hasSchedules ? FontWeight.w600 : FontWeight.normal),
                          color: textColor,
                        ),
                      ),
                      
                      // 4. Schedule Marker: Single small bar at bottom
                      if (hasSchedules)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: AppColors.sand,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
