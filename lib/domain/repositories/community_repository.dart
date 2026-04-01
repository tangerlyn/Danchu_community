import 'dart:io';
import '../entities/community_post.dart';
import '../entities/community_comment.dart';
import '../entities/comment_reply.dart';

abstract class CommunityRepository {
  /// Fetch all posts ordered by newest
  Stream<List<CommunityPost>> getPostsStream({String? mainCategory, String? subCategory});

  /// Get a single post
  Future<CommunityPost?> getPostById(String postId);

  /// Create a new post (handles image uploads internally for atomicity)
  Future<List<String>> createPost(CommunityPost post, List<File> imageFiles);

  /// Delete a post
  Future<void> deletePost(String postId);

  /// Update a post
  Future<void> updatePost(String postId, String title, String content, {Map<String, dynamic>? petInfo, List<IncidentLocation>? incidentLocations, List<String>? imageUrls});

  /// Toggle Like
  Future<void> toggleLike(String postId, String userId);

  /// Add a comment
  Future<void> addComment(String postId, CommunityComment comment);

  /// Update a comment
  Future<void> updateComment(String postId, String commentId, String newContent);

  /// Get comments stream
  Stream<List<CommunityComment>> getCommentsStream(String postId);

  /// Delete a comment
  Future<void> deleteComment(String postId, String commentId);

  /// Record a view (deduplicated by user UID)
  Future<void> recordView(String postId, String userId);

  /// Report a post
  Future<void> reportPost(String postId, String userId);

  /// Report a comment
  Future<void> reportComment(String postId, String commentId, String userId);

  /// Toggle Meetup Participation
  Future<void> toggleMeetupParticipation(String postId, String userId);

  /// Stream to get participants UIDs of a meetup
  Stream<List<String>> getMeetupParticipantsStream(String postId);

  /// Add a reply to a comment
  Future<void> addReply(String postId, String commentId, CommentReply reply);

  /// Get replies stream for a comment
  Stream<List<CommentReply>> getRepliesStream(String postId, String commentId);

  /// Delete a reply
  Future<void> deleteReply(String postId, String commentId, String replyId);
}

