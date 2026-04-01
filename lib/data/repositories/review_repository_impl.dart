import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/place_review.dart';
import '../../domain/repositories/review_repository.dart';
import '../models/place_review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final FirebaseFirestore _firestore;

  ReviewRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<PlaceReview>> getReviews(String placeId) async {
    final snapshot = await _firestore
        .collection('place_reviews')
        .where('placeId', isEqualTo: placeId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => PlaceReviewModel.fromFirestore(doc)).toList();
  }

  @override
  Future<(double, int)> getPlaceRatingInfo(String placeId) async {
    final snapshot = await _firestore
        .collection('place_reviews')
        .where('placeId', isEqualTo: placeId)
        .get();

    if (snapshot.docs.isEmpty) {
      return (0.0, 0);
    }

    double totalRating = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalRating += (data['rating'] as num?)?.toDouble() ?? 5.0;
    }

    final average = totalRating / snapshot.docs.length;
    return (average, snapshot.docs.length);
  }

  @override
  Future<void> addReview({
    required String placeId,
    required String authorUid,
    required String authorNickname,
    required int rating,
    required String content,
  }) async {
    final docRef = _firestore.collection('place_reviews').doc();
    final model = PlaceReviewModel(
      id: docRef.id,
      placeId: placeId,
      authorUid: authorUid,
      authorNickname: authorNickname,
      rating: rating,
      content: content,
      createdAt: DateTime.now(), // Real timestamp handled by Model.toMap()
    );

    await docRef.set(model.toMap());
  }

  @override
  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String content,
  }) async {
    await _firestore.collection('place_reviews').doc(reviewId).update({
      'rating': rating,
      'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection('place_reviews').doc(reviewId).delete();
  }
}
