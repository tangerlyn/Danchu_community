import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleEvent {
  final String id;
  final String uid;
  final String category; // '동물병원', '예방접종', '미용', '산책 약속', '기타'
  final DateTime dateTime;
  final String memo;
  final String dogName;
  final DateTime createdAt;

  ScheduleEvent({
    required this.id,
    required this.uid,
    required this.category,
    required this.dateTime,
    this.memo = '',
    required this.dogName,
    required this.createdAt,
  });

  factory ScheduleEvent.fromMap(String id, Map<String, dynamic> data) {
    return ScheduleEvent(
      id: id,
      uid: data['uid'] ?? '',
      category: data['category'] ?? '기타',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      memo: data['memo'] ?? '',
      dogName: data['dogName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'category': category,
      'dateTime': Timestamp.fromDate(dateTime),
      'memo': memo,
      'dogName': dogName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }


  static const List<String> categories = [
    '직접 입력',
    '동물병원',
    '미용',
    '산책 약속',
  ];
}
