import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderNickname;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderNickname,
    required this.message,
    this.imageUrl,
    required this.createdAt,
    this.readBy = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    return ChatMessage(
      id: id,
      senderUid: json['senderUid'] ?? '',
      senderNickname: json['senderNickname'] ?? '',
      message: json['message'] ?? '',
      imageUrl: json['imageUrl'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(json['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'senderNickname': senderNickname,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': Timestamp.now(),
      'readBy': readBy,
    };
  }
}
