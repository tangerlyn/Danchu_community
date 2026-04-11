import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  final String id;
  final String uid;
  final String nickname;
  final String? profileImageUrl;
  final String message;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  JoinRequest({
    required this.id,
    required this.uid,
    required this.nickname,
    this.profileImageUrl,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json, String id) {
    return JoinRequest(
      id: id,
      uid: json['uid'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      message: json['message'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'message': message,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
