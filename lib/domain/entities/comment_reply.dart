import 'package:cloud_firestore/cloud_firestore.dart';

class CommentReply {
  final String id;
  final String authorUid;
  final String authorNickname;
  final String content;
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final bool isEdited;

  CommentReply({
    required this.id,
    required this.authorUid,
    required this.authorNickname,
    required this.content,
    this.authorProfileImageUrl,
    required this.createdAt,
    this.isEdited = false,
  });

  factory CommentReply.fromJson(Map<String, dynamic> json, String id) {
    return CommentReply(
      id: id,
      authorUid: json['authorUid'] ?? '',
      authorNickname: json['authorNickname'] ?? '',
      content: json['content'] ?? '',
      authorProfileImageUrl: json['authorProfileImageUrl'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: json['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'content': content,
      if (authorProfileImageUrl != null) 'authorProfileImageUrl': authorProfileImageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isEdited': isEdited,
    };
  }
}