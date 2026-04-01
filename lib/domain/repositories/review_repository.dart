import '../entities/place_review.dart';

abstract class ReviewRepository {
  /// Fetch all reviews for a specific place
  Future<List<PlaceReview>> getReviews(String placeId);

  /// Get the average rating and review count for a designated place
  Future<(double averageRating, int reviewCount)> getPlaceRatingInfo(String placeId);

  /// Add a new review to a place
  Future<void> addReview({
    required String placeId,
    required String authorUid,
    required String authorNickname,
    required int rating,
    required String content,
  });
  /// Update an existing review
  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String content,
  });

  /// Delete an existing review
  Future<void> deleteReview(String reviewId);
}
