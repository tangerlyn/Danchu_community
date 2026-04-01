import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  final String id;
  final String authorUid;
  final String authorNickname;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final int reportCount;
  final List<String> reportedBy;
  final String? authorProfileImageUrl;
  final bool isDeleted;

  CommunityComment({
    required this.id,
    required this.authorUid,
    required this.authorNickname,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.reportCount = 0,
    this.reportedBy = const [],
    this.authorProfileImageUrl,
    this.isDeleted = false,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json, String id) {
    return CommunityComment(
      id: id,
      authorUid: json['authorUid'] ?? '',
      authorNickname: json['authorNickname'] ?? '',
      content: json['content'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      isEdited: json['isEdited'] ?? false,
      reportCount: json['reportCount'] ?? 0,
      reportedBy: List<String>.from(json['reportedBy'] ?? []),
      authorProfileImageUrl: json['authorProfileImageUrl'],
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isEdited': isEdited,
      'reportCount': reportCount,
      'reportedBy': reportedBy,
      if (authorProfileImageUrl != null) 'authorProfileImageUrl': authorProfileImageUrl,
      'isDeleted': isDeleted,
    };
  }
}
