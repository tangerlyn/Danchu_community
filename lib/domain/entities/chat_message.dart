import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderNickname;
  final String message;
  final String? imageUrl;
  final List<String> imageUrls;
  final String type;
  final DateTime createdAt;
  final List<String> readBy;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderNickname,
    required this.message,
    this.imageUrl,
    this.imageUrls = const [],
    this.type = 'normal',
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
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      type: json['type'] ?? 'normal',
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
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      'type': type,
      'createdAt': Timestamp.now(),
      'readBy': readBy,
    };
  }
}
