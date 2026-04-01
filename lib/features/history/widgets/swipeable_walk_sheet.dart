import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/schedule_event.dart';
import '../walk_model.dart';
import 'walk_card.dart';
import 'add_schedule_sheet.dart';

class SwipeableWalkSheet extends StatefulWidget {
  final DateTime initialDate;
  final List<Walk> Function(DateTime) getWalksForDay;
  final List<ScheduleEvent> Function(DateTime) getSchedulesForDay;
  final Map<String, Color> dogColors;
  final void Function(DateTime) onDateChanged;
  final void Function(Walk) onWalkTap;
  final void Function(ScheduleEvent) onScheduleDelete;
  final VoidCallback onScheduleSaved;

  const SwipeableWalkSheet({
    super.key,
    required this.initialDate,
    required this.getWalksForDay,
    required this.getSchedulesForDay,
    required this.dogColors,
    required this.onDateChanged,
    required this.onWalkTap,
    required this.onScheduleDelete,
    required this.onScheduleSaved,
  });

  @override
  State<SwipeableWalkSheet> createState() => _SwipeableWalkSheetState();
}

class _SwipeableWalkSheetState extends State<SwipeableWalkSheet> {
  late DateTime _currentDate;
  late List<Walk> _currentWalks;
  late List<ScheduleEvent> _currentSchedules;

  // For swipe animation
  double _dragOffset = 0;
  static const double _swipeThreshold = 60;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
    _currentWalks = widget.getWalksForDay(_currentDate);
    _currentSchedules = widget.getSchedulesForDay(_currentDate);
  }

  void _goToDate(DateTime newDate) {
    setState(() {
      _currentDate = newDate;
      _currentWalks = widget.getWalksForDay(newDate);
      _currentSchedules = widget.getSchedulesForDay(newDate);
    });
    widget.onDateChanged(newDate);
  }

  void _goToPreviousDay() {
    _goToDate(_currentDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    _goToDate(_currentDate.add(const Duration(days: 1)));
  }

  void _showAddScheduleSheet() {
    Navigator.pop(context); // Close current sheet first
    showModalBottomSheet(
      context: Navigator.of(context, rootNavigator: true).context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AddScheduleSheet(
          initialDate: _currentDate,
          onSaved: widget.onScheduleSaved,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _currentWalks.isNotEmpty || _currentSchedules.isNotEmpty;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > _swipeThreshold) {
          _goToPreviousDay();
        } else if (_dragOffset < -_swipeThreshold) {
          _goToNextDay();
        }
        setState(() {
          _dragOffset = 0;
        });
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Date header with arrows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.deepBrown),
                    onPressed: _goToPreviousDay,
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            DateFormat('yyyy년 M월 d일', 'ko').format(_currentDate),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE', 'ko').format(_currentDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.taupe,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.deepBrown),
                    onPressed: _goToNextDay,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content list (walks + schedules)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: !hasContent
                    ? Center(
                        key: ValueKey('empty-$_currentDate'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pets, size: 48, color: AppColors.sand),
                            const SizedBox(height: 12),
                            Text(
                              "이 날은 기록이 없어요",
                              style: TextStyle(color: AppColors.taupe, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        key: ValueKey('list-$_currentDate'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // Schedules section
                          if (_currentSchedules.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                '일정',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.deepBrown,
                                ),
                              ),
                            ),
                            ..._currentSchedules.map((schedule) => _scheduleCard(schedule)),
                            if (_currentWalks.isNotEmpty) const SizedBox(height: 12),
                          ],
                          // Walks section
                          if (_currentWalks.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.deepBrown,
                                    ),
                                    children: [
                                      WidgetSpan(
                                        child: Icon(Icons.pets, size: 16, color: AppColors.deepBrown),
                                        alignment: PlaceholderAlignment.middle,
                                      ),
                                      TextSpan(text: ' 산책 기록'),
                                    ],
                                  ),
                                ),
                            ),
                            ..._currentWalks.map((walk) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: WalkCard(
                                walk: walk,
                                dogColors: widget.dogColors,
                                onTap: () => widget.onWalkTap(walk),
                              ),
                            )),
                          ],
                        ],
                      ),
              ),
            ),

            // Add schedule button at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddScheduleSheet,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    '일정 추가',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBrown,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleCard(ScheduleEvent schedule) {
    final timeStr = DateFormat('HH:mm').format(schedule.dateTime);

    return Dismissible(
      key: Key(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.white, size: 22),
      ),
      onDismissed: (_) {
        widget.onScheduleDelete(schedule);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5F1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sand, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        schedule.category,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBrown,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.deepBrown.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          schedule.dogName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mocha,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$timeStr${schedule.memo.isNotEmpty ? ' · ${schedule.memo}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.taupe,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
