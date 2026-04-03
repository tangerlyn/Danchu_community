import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/local_notification_service.dart';
import '../../data/models/schedule_event.dart';
import '../../data/repositories/schedule_repository.dart';
import 'database_helper.dart';
import 'walk_model.dart';
import 'walk_detail_page.dart';
import 'utils/dog_color_palette.dart';
import 'widgets/month_block.dart';
import 'widgets/swipeable_walk_sheet.dart';
import 'widgets/add_schedule_sheet.dart';

// ─── HistoryPage ───────────────────────────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  Map<String, List<Walk>> _walksByDate = {};
  Map<String, Color> _dogColors = {};
  Map<String, List<ScheduleEvent>> _schedulesByDate = {};
  bool _isLoading = true;

  /// Currently selected (tapped) date — null means nothing selected
  DateTime? _selectedDate;

  final ScrollController _scrollController = ScrollController();
  final ScheduleRepository _scheduleRepo = ScheduleRepository();

  static const int _monthsBefore = 36;
  static const int _totalMonths = 73;

  late final DateTime _baseMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonth = DateTime(now.year, now.month - _monthsBefore, 1);
    _loadAllData();
    // Initialize notification service
    LocalNotificationService.init();
  }

  void refreshWalks() {
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final walks = await DatabaseHelper.instance.readAllWalks();
    final Map<String, List<Walk>> grouped = {};

    for (final walk in walks) {
      final key = _dateKey(walk.startTime);
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(walk);
    }

    // Load schedules from Firestore
    Map<String, List<ScheduleEvent>> schedulesGrouped = {};
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        final start = _baseMonth;
        final end = DateTime(_baseMonth.year, _baseMonth.month + _totalMonths, 1);
        final schedules = await _scheduleRepo.getSchedulesForRange(start, end);
        for (final s in schedules) {
          final key = _dateKey(s.dateTime);
          schedulesGrouped.putIfAbsent(key, () => []);
          schedulesGrouped[key]!.add(s);
        }
      }
    } catch (e) {
      debugPrint('Failed to load schedules: $e');
    }

    if (mounted) {
      setState(() {
        _walksByDate = grouped;
        _dogColors = buildDogColorMap(walks);
        _schedulesByDate = schedulesGrouped;
        _isLoading = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToToday();
      });
    });
  }

  void _scrollToToday() {
    if (!_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;

    final now = DateTime.now();
    double offset = 0.0;

    // 1. ListView padding
    offset += 8.0;

    // 2. Sum height of previous months
    for (int i = 0; i < _monthsBefore; i++) {
      offset += _estimateMonthHeight(_monthAt(i));
    }

    // 3. Add height within current month block
    offset += 16.0; // Top padding
    offset += 24.0; // Title area height (approx)
    
    final walksInMonth = _getWalksCountForMonth(_monthAt(_monthsBefore));
    if (walksInMonth > 0) {
      offset += 34.0; // Stats row
    } else {
      offset += 8.0; // Spacer
    }
    
    offset += 20.0; // Weekday labels
    offset += 8.0;  // Spacer

    // 4. Calculate rows to today
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;
    final rowOfToday = ((now.day + firstWeekday - 1) / 7).floor();
    offset += rowOfToday * 56.0; // 48 height + 8 total vertical margin

    // 5. Center it (move up by roughly half screen height)
    final screenHeight = MediaQuery.of(context).size.height;
    offset -= (screenHeight / 2) - 100; // Center offset adjustment

    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo(offset.clamp(0.0, maxScroll));
  }

  double _estimateMonthHeight(DateTime month) {
    double h = 32.0; // Padding (16*2)
    h += 24.0; // Title
    
    if (_getWalksCountForMonth(month) > 0) {
      h += 34.0; // Stats row
    } else {
      h += 8.0; // Spacer
    }
    
    h += 20.0; // Weekdays row
    h += 8.0;  // Spacer
    
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final rows = ((firstWeekday + daysInMonth) / 7).ceil();
    h += rows * 56.0; // Day grid (48 + 8)
    
    h += 24.0; // Bottom margin
    return h;
  }

  int _getWalksCountForMonth(DateTime month) {
    int count = 0;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (int d = 1; d <= daysInMonth; d++) {
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      count += (_walksByDate[key] ?? []).length;
    }
    return count;
  }



  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Walk> _getWalksForDay(DateTime day) {
    return _walksByDate[_dateKey(day)] ?? [];
  }

  List<ScheduleEvent> _getSchedulesForDay(DateTime day) {
    return _schedulesByDate[_dateKey(day)] ?? [];
  }

  void _onDayTapped(DateTime day) {
    if (mounted) {
      setState(() {
        _selectedDate = day;
      });
    }
    _showSwipeablePanel(day);
  }

  void _onDayLongPressed(DateTime day) {
    _showAddScheduleSheet(day);
  }

  void _showAddScheduleSheet([DateTime? date]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AddScheduleSheet(
          initialDate: date,
          onSaved: () {
            _loadAllData(); // Refresh schedules after saving
          },
        );
      },
    );
  }

  void _onScheduleDelete(ScheduleEvent schedule) async {
    try {
      await _scheduleRepo.deleteSchedule(schedule.id);
      // Cancel the associated notification
      await LocalNotificationService.cancelScheduleNotification(
        LocalNotificationService.generateId(schedule.category, schedule.dateTime),
      );
      _loadAllData();
    } catch (e) {
      debugPrint('Failed to delete schedule: $e');
    }
  }

  /// Show the bottom sheet with left/right swipe to change dates
  void _showSwipeablePanel(DateTime initialDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SwipeableWalkSheet(
          initialDate: initialDate,
          getWalksForDay: _getWalksForDay,
          getSchedulesForDay: _getSchedulesForDay,
          dogColors: _dogColors,
          onDateChanged: (newDate) {
            // Sync calendar highlight when user swipes
            if (mounted) {
              setState(() {
                _selectedDate = newDate;
              });
            }
          },
          onWalkTap: (walk) {
            Navigator.pop(sheetContext);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WalkDetailPage(walk: walk)),
            );
          },
          onScheduleDelete: _onScheduleDelete,
          onScheduleSaved: () => _loadAllData(),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _selectedDate = null;
        });
      }
    });
  }

  DateTime _monthAt(int index) {
    return DateTime(_baseMonth.year, _baseMonth.month + index, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      appBar: AppBar(
        title: const Text('산책 기록', style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3E2723),
          letterSpacing: -0.5,
        )),
        titleSpacing: 24,
        centerTitle: false,
        backgroundColor: const Color(0xFFF8F5F1),
        elevation: 0,
        toolbarHeight: 64, // Increased to match the SafeArea + 16 vertical offset effect
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _totalMonths,
              itemBuilder: (context, index) {
                final month = _monthAt(index);
                return MonthBlock(
                  month: month,
                  walksByDate: _walksByDate,
                  dogColors: _dogColors,
                  schedulesByDate: _schedulesByDate,
                  selectedDate: _selectedDate,
                  onDayTapped: _onDayTapped,
                  onDayLongPressed: _onDayLongPressed,
                );
              },
            ),
    );
  }
}
