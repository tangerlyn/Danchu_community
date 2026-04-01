import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/place_review.dart';

class PlaceReviewModel extends PlaceReview {
  PlaceReviewModel({
    required super.id,
    required super.placeId,
    required super.authorUid,
    required super.authorNickname,
    required super.rating,
    required super.content,
    required super.createdAt,
  });

  factory PlaceReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlaceReviewModel(
      id: doc.id,
      placeId: data['placeId'] ?? '',
      authorUid: data['authorUid'] ?? '',
      authorNickname: data['authorNickname'] ?? '알 수 없음',
      rating: data['rating'] ?? 5,
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'authorUid': authorUid,
      'authorNickname': authorNickname,
      'rating': rating,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
