import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderNickname;
  final String message;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final String type;
  final DateTime createdAt;
  final List<String> readBy;

  // 산책 공유용 필드
  final List<Map<String, double>>? walkRoutePoints; // [[lat, lng], ...]
  final String? walkDate; // "2024년 4월 20일"
  final String? walkDogNames; // "초코, 뭉치"

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderNickname,
    required this.message,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.videoThumbnailUrl,
    this.type = 'normal',
    required this.createdAt,
    this.readBy = const [],
    this.walkRoutePoints,
    this.walkDate,
    this.walkDogNames,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    final walkPoints = (json['walkRoutePoints'] as List?)
        ?.map((p) => Map<String, double>.from(
            (p as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))
        .toList();
    debugPrint('🗺️ fromJson walkRoutePoints: ${walkPoints?.length}');

    return ChatMessage(
      id: id,
      senderUid: json['senderUid'] ?? '',
      senderNickname: json['senderNickname'] ?? '',
      message: json['message'] ?? '',
      imageUrl: json['imageUrl'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      videoUrl: json['videoUrl'],
      videoThumbnailUrl: json['videoThumbnailUrl'],
      type: json['type'] ?? 'normal',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(json['readBy'] ?? []),
      walkRoutePoints: walkPoints,
      walkDate: json['walkDate'],
      walkDogNames: json['walkDogNames'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'senderNickname': senderNickname,
      'message': message,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (videoThumbnailUrl != null) 'videoThumbnailUrl': videoThumbnailUrl,
      'type': type,
      'createdAt': Timestamp.now(),
      'readBy': readBy,
      if (walkRoutePoints != null) 'walkRoutePoints': walkRoutePoints,
      if (walkDate != null) 'walkDate': walkDate,
      if (walkDogNames != null) 'walkDogNames': walkDogNames,
    };
  }
}
