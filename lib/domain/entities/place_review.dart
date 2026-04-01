class PlaceReview {
  final String id;
  final String placeId;
  final String authorUid;
  final String authorNickname;
  final int rating;
  final String content;
  final DateTime createdAt;

  PlaceReview({
    required this.id,
    required this.placeId,
    required this.authorUid,
    required this.authorNickname,
    required this.rating,
    required this.content,
    required this.createdAt,
  });
}
