import 'dart:async';
import 'package:get/get.dart';
import '../../data/models/dog_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../history/walk_model.dart';
import '../history/walk_repository.dart';

class DailyWalkData {
  final DateTime date;
  final double distance;
  DailyWalkData(this.date, this.distance);
}

class StatsController extends GetxController {
  final WalkRepository _repository = WalkRepository();

  var isLoading = true.obs;
  
  // Current period stats
  var walkCount = 0.obs;
  var totalDistance = 0.0.obs;
  var totalDurationMinutes = 0.obs;

  // Comparison stats (vs previous period)
  var countChange = 0.obs;
  var distanceChange = 0.0.obs;
  var durationChange = 0.obs;

  // Chart data
  var dailyData = <DailyWalkData>[].obs;

  // Streak data (All-time based)
  var currentStreak = 0.obs;
  var longestStreak = 0.obs;

  // Dog stats
  var dogStats = <String, DogStat>{}.obs;
  var dogProfiles = <String, DogProfile>{}.obs; // key: dogName

  final selectedDayIndex = RxInt(-1);
  final isDaySelected = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllData('이번 주');
  }

  Future<void> loadAllData(String period) async {
    isLoading.value = true;
    selectedDayIndex.value = -1;
    
    // 강아지 프로필 먼저 로드
    await _loadDogProfiles();

    final allWalks = await _repository.getAllWalks();
    
    // 1. Calculate Streaks (All-time)
    _calculateStreaks(allWalks);

    // 2. Calculate Period-specific stats
    _calculatePeriodStats(allWalks, period);

    isLoading.value = false;
  }

  Future<void> _loadDogProfiles() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('dogs')
          .get();

      final profiles = <String, DogProfile>{};
      for (final doc in snapshot.docs) {
        final dog = DogProfile.fromMap(doc.id, doc.data());
        profiles[dog.dogName] = dog;
      }
      dogProfiles.value = profiles;
    } catch (e) {
      // 프로필 로드 실패해도 통계는 정상 표시
    }
  }

  void _calculateStreaks(List<Walk> allWalks) {
    if (allWalks.isEmpty) {
      currentStreak.value = 0;
      longestStreak.value = 0;
      return;
    }

    // Sort by date ascending to calculate streak
    final sortedWalks = List<Walk>.from(allWalks)..sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Unique dates with walks
    final walkDates = sortedWalks.map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day)).toSet().toList()..sort();

    int maxStreak = 0;
    int current = 0;
    DateTime? lastDate;

    for (var date in walkDates) {
      if (lastDate == null) {
        current = 1;
      } else {
        final diff = date.difference(lastDate).inDays;
        if (diff == 1) {
          current++;
        } else {
          current = 1;
        }
      }
      if (current > maxStreak) maxStreak = current;
      lastDate = date;
    }

    longestStreak.value = maxStreak;

    // Current Streak calculation
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (walkDates.contains(today) || walkDates.contains(yesterday)) {
      // Find the current active streak ending at today or yesterday
      int activeStreak = 0;
      DateTime checkDate = walkDates.contains(today) ? today : yesterday;
      
      while (walkDates.contains(checkDate)) {
        activeStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      currentStreak.value = activeStreak;
    } else {
      currentStreak.value = 0;
    }
  }

  void _calculatePeriodStats(List<Walk> allWalks, String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime prevStart;
    DateTime prevEnd;

    if (period == '이번 주') {
      start = now.subtract(Duration(days: now.weekday % 7));
      start = DateTime(start.year, start.month, start.day);
      prevStart = start.subtract(const Duration(days: 7));
      prevEnd = start.subtract(const Duration(seconds: 1));
    } else if (period == '이번 달') {
      start = DateTime(now.year, now.month, 1);
      prevStart = DateTime(now.year, now.month - 1, 1);
      prevEnd = start.subtract(const Duration(seconds: 1));
    } else { // '이번 년'
      start = DateTime(now.year, 1, 1);
      prevStart = DateTime(now.year - 1, 1, 1);
      prevEnd = start.subtract(const Duration(seconds: 1));
    }

    final currentWalks = allWalks.where((w) => w.startTime.isAfter(start.subtract(const Duration(seconds: 1))) && w.startTime.isBefore(end.add(const Duration(seconds: 1)))).toList();
    final previousWalks = allWalks.where((w) => w.startTime.isAfter(prevStart.subtract(const Duration(seconds: 1))) && w.startTime.isBefore(prevEnd.add(const Duration(seconds: 1)))).toList();

    // Current totals
    walkCount.value = currentWalks.length;
    totalDistance.value = currentWalks.fold(0.0, (sum, w) => sum + w.distanceMeters) / 1000.0;
    totalDurationMinutes.value = currentWalks.fold(0, (sum, w) => sum + w.durationSeconds) ~/ 60;

    // Previous totals for comparison
    final prevCount = previousWalks.length;
    final prevDistance = previousWalks.fold(0.0, (sum, w) => sum + w.distanceMeters) / 1000.0;
    final prevDuration = previousWalks.fold(0, (sum, w) => sum + w.durationSeconds) ~/ 60;

    countChange.value = walkCount.value - prevCount;
    distanceChange.value = totalDistance.value - prevDistance;
    durationChange.value = totalDurationMinutes.value - prevDuration;

    // Daily Chart Data
    _calculateChartData(currentWalks, start, period);

    // Dog Stats
    _calculateDogStats(currentWalks);
  }

  void _calculateChartData(List<Walk> walks, DateTime start, String period) {
    final Map<DateTime, double> dailyMap = {};
    int days;
    if (period == '이번 주') {
      days = 7;
    } else if (period == '이번 달') {
      days = DateTime(start.year, start.month + 1, 0).day;
    } else {
      days = 12; // Months
    }

    if (period == '이번 년') {
      for (int i = 1; i <= 12; i++) {
        final monthStart = DateTime(start.year, i, 1);
        final monthEnd = DateTime(start.year, i + 1, 0);
        final monthWalks = walks.where((w) => w.startTime.isAfter(monthStart.subtract(const Duration(seconds: 1))) && w.startTime.isBefore(monthEnd.add(const Duration(seconds: 1))));
        final dist = monthWalks.fold(0.0, (sum, w) => sum + w.distanceMeters) / 1000.0;
        dailyMap[monthStart] = dist;
      }
    } else {
      for (int i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
        final dayWalks = walks.where((w) => w.startTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) && w.startTime.isBefore(dayEnd.add(const Duration(seconds: 1))));
        final dist = dayWalks.fold(0.0, (sum, w) => sum + w.distanceMeters) / 1000.0;
        dailyMap[dayStart] = dist;
      }
    }

    dailyData.value = dailyMap.entries.map((e) => DailyWalkData(e.key, e.value)).toList()..sort((a,b) => a.date.compareTo(b.date));
  }

  void _calculateDogStats(List<Walk> walks) {
    final stats = <String, DogStat>{};
    for (final walk in walks) {
      for (final name in walk.dogNameList) {
        stats.putIfAbsent(name, () => DogStat());
        stats[name]!.walkCount++;
        stats[name]!.totalDistance += walk.distanceMeters / 1000.0;
        stats[name]!.totalMinutes += walk.durationSeconds ~/ 60;

        // 프로필 이미지 URL 연결 (이름으로 매칭)
        final profile = dogProfiles[name];
        if (profile != null && profile.profileImageUrl.isNotEmpty) {
          stats[name]!.profileImageUrl = profile.profileImageUrl;
        }
      }
    }
    dogStats.value = stats;
  }
}

class DogStat {
  int walkCount = 0;
  double totalDistance = 0.0;
  int totalMinutes = 0;
  String profileImageUrl = '';
}
