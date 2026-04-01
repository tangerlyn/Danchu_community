import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/schedule_event.dart';

class ScheduleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _schedulesRef() {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    return _firestore.collection('users').doc(uid).collection('schedules');
  }

  /// Add a new schedule event
  Future<ScheduleEvent> addSchedule({
    required String category,
    required DateTime dateTime,
    required String dogName,
    String memo = '',
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final data = {
      'uid': uid,
      'category': category,
      'dateTime': Timestamp.fromDate(dateTime),
      'memo': memo,
      'dogName': dogName,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    final docRef = await _schedulesRef().add(data);
    return ScheduleEvent.fromMap(docRef.id, data);
  }

  /// Get all schedules for a given month
  Future<List<ScheduleEvent>> getSchedulesForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    final snapshot = await _schedulesRef()
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('dateTime')
        .get();

    return snapshot.docs
        .map((doc) => ScheduleEvent.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get all schedules for a date range (for loading visible months)
  Future<List<ScheduleEvent>> getSchedulesForRange(DateTime start, DateTime end) async {
    final snapshot = await _schedulesRef()
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('dateTime')
        .get();

    return snapshot.docs
        .map((doc) => ScheduleEvent.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Delete a schedule by ID
  Future<void> deleteSchedule(String scheduleId) async {
    await _schedulesRef().doc(scheduleId).delete();
  }
}
