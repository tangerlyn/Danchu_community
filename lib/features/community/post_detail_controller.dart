import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/entities/community_comment.dart';
import '../../domain/entities/comment_reply.dart';
import '../../domain/repositories/community_repository.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/meetup_chat_repository.dart';
import '../../services/fcm_service.dart';
import 'community_controller.dart';
import '../auth/auth_controller.dart';

class PostDetailController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
  final MeetupChatRepository _chatRepository = MeetupChatRepository();
  late CommunityPost _post;
  CommunityPost get post => _post;

  // Store current user UID eagerly for reliable author checks
  String? _currentUid;

  // Post Observation State
  final postTitle = ''.obs;
  final postContent = ''.obs;
  final createdAt = DateTime.now().obs;
  final isEdited = false.obs;

  var meetupDate = Rxn<DateTime>();
  var meetupLocation = RxnString();
  var meetupCapacity = Rxn<int>();

  final petInfo = Rxn<Map<String, dynamic>>();
  final incidentLocations = <IncidentLocation>[].obs;
  var viewCount = 0.obs;

  var isDeleting = false.obs;

  var likeCount = 0.obs;
  var isLiked = false.obs;
  var commentCount = 0.obs;

  // Meetup fields
  var meetupParticipants = <String>[].obs;
  var currentParticipantCount = 0.obs;
  var joinType = 'free'.obs;
  var hostUid = RxnString();
  var myJoinRequestStatus =
      RxnString(); // null, 'pending', 'accepted', 'rejected'

  // Deleted user tracking
  var isDeletedAuthor = false.obs;
  var deletedCommentAuthors = <String>{}.obs;

  var comments = <CommunityComment>[].obs;

  final commentTextController = TextEditingController();
  late FocusNode commentFocusNode;
  final inlineEditController = TextEditingController();
  final inlineEditFocusNode = FocusNode();
  var isSubmittingComment = false.obs;
  var isSubmittingInlineEdit = false.obs;
  var commentText = ''.obs; // Reactive text for send button state

  var editingCommentId = RxnString();
  var editingReplyId = RxnString();
  var editingReplyCommentId = RxnString();
  final inlineReplyEditController = TextEditingController();

  // Reply State
  final replyingToCommentId = RxnString();
  final replyingToNickname = RxnString();
  final commentReplies = <String, List<CommentReply>>{}.obs;

  PostDetailController({required CommunityPost post}) {
    _post = post;
  }

  @override
  void onInit() {
    super.onInit();
    commentFocusNode = FocusNode();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _initializePostData(post);

    if (post.mainCategory == '모임') {
      _repository.getMeetupParticipantsStream(post.id).listen((data) {
        meetupParticipants.value = data;
        currentParticipantCount.value = data.length;
      });
      _checkMyJoinRequestStatus();
    }

    // Record view (deduplicated)
    _recordView();

    // Check if post author is a deleted user
    _checkDeletedAuthor();

    // 댓글 스트림 구독
    _repository.getCommentsStream(post.id).listen((data) {
      // 차단된 사용자의 댓글 필터링
      final filteredComments = _filterBlockedComments(data);
      comments.value = filteredComments;

      // 각 댓글의 대댓글 스트림 구독 (필터링된 댓글에 대해서만)
      for (var comment in filteredComments) {
        _repository.getRepliesStream(post.id, comment.id).listen((replies) {
          // 차단된 사용자의 답글 필터링
          final filteredReplies = _filterBlockedReplies(replies);
          commentReplies[comment.id] = filteredReplies;
          commentReplies.refresh();

          // 총 댓글 수 = 필터링된 댓글 수 + 필터링된 답글 수 합산
          int total = comments.length;
          for (final repliesList in commentReplies.values) {
            total += repliesList.length;
          }
          commentCount.value = total;
        });
      }

      // 댓글만 있고 답글 없을 때도 업데이트
      int total = filteredComments.length;
      for (final repliesList in commentReplies.values) {
        total += repliesList.length;
      }
      commentCount.value = total;

      // 삭제된 댓글 작성자 체크 (필터링된 댓글 기준)
      _checkDeletedCommentAuthors(filteredComments);
    });

    // 차단 목록이 변경되면 댓글/답글을 다시 필터링
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      ever(auth.blockedUsers, (_) {
        _refilterCommentsAndReplies();
      });
    }
  }

  void _initializePostData(CommunityPost p) {
    postTitle.value = p.title;
    postContent.value = p.content;
    isEdited.value = p.isEdited;
    createdAt.value = p.createdAt;

    meetupDate.value = p.meetupDate;
    meetupLocation.value = p.meetupLocation;
    meetupCapacity.value = p.meetupCapacity;

    likeCount.value = p.likeCount;
    commentCount.value = p.commentCount;
    viewCount.value = p.viewCount;
    isLiked.value = _currentUid != null && p.likedBy.contains(_currentUid);
    currentParticipantCount.value = p.currentParticipantCount;
    joinType.value = p.joinType;
    hostUid.value = p.hostUid;

    petInfo.value = p.petInfo;
    if (p.incidentLocations != null) {
      incidentLocations.assignAll(p.incidentLocations!);
    } else {
      incidentLocations.clear();
    }
  }

  /// Update the internal state with new post data (called after editing)
  void updatePostData(CommunityPost updatedPost) {
    _post = updatedPost;
    _initializePostData(updatedPost);
  }

  @override
  void onClose() {
    commentTextController.dispose();
    commentFocusNode.dispose();
    inlineEditController.dispose();
    inlineEditFocusNode.dispose();
    inlineReplyEditController.dispose();
    super.onClose();
  }

  bool get isAuthor {
    return _currentUid != null && _currentUid == _post.authorUid;
  }

  String? get currentUserUid => _currentUid;

  /// Returns true if the given comment was written by the current user
  bool isMyComment(CommunityComment comment) {
    return _currentUid != null && _currentUid == comment.authorUid;
  }

  bool isMyReply(CommentReply reply) {
    return _currentUid != null && _currentUid == reply.authorUid;
  }

  Future<void> _checkDeletedAuthor() async {
    if (post.authorUid.isEmpty) {
      isDeletedAuthor.value = true;
      return;
    }
    try {
      final profile = await _profileRepository.getUserProfile(post.authorUid);
      isDeletedAuthor.value = profile == null;
    } catch (_) {
      // If we can't check, assume not deleted
    }
  }

  Future<void> _checkDeletedCommentAuthors(
    List<CommunityComment> commentList,
  ) async {
    final uniqueUids = commentList.map((c) => c.authorUid).toSet();
    for (final uid in uniqueUids) {
      if (uid.isEmpty || deletedCommentAuthors.contains(uid)) continue;
      try {
        final profile = await _profileRepository.getUserProfile(uid);
        if (profile == null) {
          deletedCommentAuthors.add(uid);
        }
      } catch (_) {}
    }
  }

  Future<void> _recordView() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Skip if already viewed by this user
    if (post.viewedBy.contains(uid)) return;
    // Optimistic update
    viewCount.value++;
    try {
      await _repository.recordView(post.id, uid);
    } catch (e) {
      viewCount.value--; // Revert on failure
    }
  }

  Future<void> deletePost() async {
    isDeleting.value = true;
    try {
      await _repository.deletePost(post.id);
      Get.back(); // close dialog
      Get.back(); // return to list screen
    } catch (e) {
      debugPrint('⚠️ Error deleting post: $e');
      Get.snackbar('잠깐!', '글 삭제에 실패했어요. 다시 시도해주세요 🐾');
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> reportPost() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '게시글 신고',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('이 게시글을 신고하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _repository.reportPost(post.id, uid);
                Get.snackbar('알림', '신고가 접수되었습니다.');
              } catch (e) {
                debugPrint('⚠️ Error reporting post: $e');
                if (e.toString().contains('already reported')) {
                  Get.snackbar('알림', '이미 신고한 게시글이에요.');
                } else {
                  Get.snackbar('잠깐!', '신고 접수에 실패했어요. 다시 시도해주세요 🐾');
                }
              }
            },
            child: const Text(
              '신고',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    // Optimistic Update
    if (isLiked.value) {
      isLiked.value = false;
      likeCount.value--;
    } else {
      isLiked.value = true;
      likeCount.value++;
    }

    try {
      await _repository.toggleLike(post.id, uid);
    } catch (e) {
      // Revert if failed
      if (isLiked.value) {
        isLiked.value = false;
        likeCount.value--;
      } else {
        isLiked.value = true;
        likeCount.value++;
      }
      debugPrint('⚠️ Error toggling like: $e');
    }
  }

  Future<void> _checkMyJoinRequestStatus() async {
    if (_currentUid == null || post.mainCategory != '모임') return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(post.id)
          .collection('join_requests')
          .doc(_currentUid)
          .get();

      if (doc.exists) {
        myJoinRequestStatus.value = doc.data()?['status'];
      } else {
        myJoinRequestStatus.value = null;
      }
    } catch (e) {
      debugPrint('Error checking join request status: $e');
    }
  }

  Future<void> submitJoinRequest(String message) async {
    if (_currentUid == null) return;

    try {
      final userProfile = await _profileRepository.getUserProfile(_currentUid!);
      await _repository.submitJoinRequest(
        post.id,
        _currentUid!,
        userProfile?.nickname ?? '알 수 없음',
        userProfile?.profileImageUrl,
        message,
      );

      myJoinRequestStatus.value = 'pending';
      Get.snackbar('알림', '참가 신청이 완료되었습니다. 단장의 승인을 기다려주세요.');
    } catch (e) {
      debugPrint('Error submitting join request: $e');
      Get.snackbar('잠깐!', '신청 중 문제가 발생했어요. 다시 시도해주세요 🐾');
    }
  }

  Future<void> toggleMeetupParticipation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    final isParticipating = meetupParticipants.contains(uid);

    // Optimistic Update
    if (isParticipating) {
      meetupParticipants.remove(uid);
      currentParticipantCount.value--;
    } else {
      final capacity = post.meetupCapacity;
      if (capacity != null && currentParticipantCount.value >= capacity) {
        Get.snackbar('알림', '모임 인원이 마감되었습니다.');
        return;
      }
      meetupParticipants.add(uid);
      currentParticipantCount.value++;
    }

    try {
      await _repository.toggleMeetupParticipation(post.id, uid);

      // Update the badge cache in CommunityController if it exists
      if (!isParticipating) {
        // Notify Author of new participation
        final userProfile = await _profileRepository.getUserProfile(uid);
        final nickname = userProfile?.nickname ?? '알 수 없음';

        FcmService.sendMeetupJoinNotification(
          postAuthorUid: post.authorUid,
          joinerNickname: nickname,
          postTitle: post.title,
          postId: post.id,
          currentUid: uid,
        );

        // Send system message
        try {
          await _chatRepository.sendSystemMessage(
            post.id,
            '${nickname}님이 참가했습니다.',
          );
        } catch (_) {}
      }

      if (Get.isRegistered<CommunityController>()) {
        Get.find<CommunityController>().refreshMyMeetupPostIds();
      }
    } catch (e) {
      // Revert if failed
      if (isParticipating) {
        meetupParticipants.add(uid);
        currentParticipantCount.value++;
      } else {
        meetupParticipants.remove(uid);
        currentParticipantCount.value--;
      }
      debugPrint('⚠️ Error toggling meetup participation: $e');
      if (e.toString().contains('마감')) {
        Get.snackbar('알림', '모임 인원이 마감되었습니다.');
      } else {
        Get.snackbar('잠깐!', '처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요 🐾');
      }
    }
  }

  void startEditingComment(CommunityComment comment) {
    cancelEditingReply(); // 답글 수정 중이면 취소
    editingCommentId.value = comment.id;
    inlineEditController.text = comment.content;
    inlineEditFocusNode.requestFocus();
  }

  void cancelEditingComment() {
    editingCommentId.value = null;
    inlineEditController.clear();
    inlineEditFocusNode.unfocus();
  }

  void startReply(String commentId, String nickname) {
    replyingToCommentId.value = commentId;
    replyingToNickname.value = nickname;
    commentFocusNode.requestFocus();
  }

  void cancelReply() {
    replyingToCommentId.value = null;
    replyingToNickname.value = null;
  }

  Future<void> submitComment() async {
    final content = commentText.value.trim();
    if (content.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    // 모임 게시글도 누구나 댓글 작성 가능

    isSubmittingComment.value = true;
    try {
      final userProfile = await _profileRepository.getUserProfile(user.uid);
      final nickname = userProfile?.nickname ?? '알 수 없음';

      if (replyingToCommentId.value != null) {
        if (replyingToCommentId.value == null || replyingToCommentId.value!.isEmpty) {
          cancelReply();
          return;
        }

        // Submit Reply
        final newReply = CommentReply(
          id: _repository.getNewDocId(),
          authorUid: user.uid,
          authorNickname: nickname,
          authorProfileImageUrl: userProfile?.profileImageUrl,
          content: content,
          createdAt: DateTime.now(),
        );
        await _repository.addReply(
          post.id,
          replyingToCommentId.value!,
          newReply,
        );

        // Notify Comment Author
        final commentId = replyingToCommentId.value!;
        final parentComment = comments.firstWhereOrNull(
          (c) => c.id == commentId,
        );
        if (parentComment != null && parentComment.authorUid.isNotEmpty) {
          // 답글 알림 전 설정 확인
          final prefDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(parentComment.authorUid)
              .collection('notification_settings')
              .doc('preferences')
              .get();
          final replyEnabled = prefDoc.data()?['reply'] ?? true;

          if (replyEnabled) {
            FcmService.sendReplyNotification(
              commentAuthorUid: parentComment.authorUid,
              replierNickname: nickname,
              postId: post.id,
              currentUid: user.uid,
            );
          }
        }

        // Notify other participants in the same thread
        final otherRepliers =
            commentReplies[commentId]
                ?.map((r) => r.authorUid)
                .where(
                  (uid) => uid != user.uid && uid != parentComment?.authorUid,
                )
                .toSet()
                .toList() ??
            [];

        if (otherRepliers.isNotEmpty) {
          FcmService.sendThreadReplyNotification(
            notifyUids: otherRepliers,
            replierNickname: nickname,
            postId: post.id,
            currentUid: user.uid,
          );
        }

        cancelReply();
      } else {
        // Submit Main Comment
        final newComment = CommunityComment(
          id: _repository.getNewDocId(),
          authorUid: user.uid,
          authorNickname: nickname,
          authorProfileImageUrl: userProfile?.profileImageUrl,
          content: content,
          createdAt: DateTime.now(),
        );
        await _repository.addComment(post.id, newComment);

        // Notify Post Author
        FcmService.sendCommentNotification(
          postAuthorUid: post.authorUid,
          commenterNickname: nickname,
          postTitle: post.title,
          postId: post.id,
          currentUid: user.uid,
        );
      }

      commentTextController.clear();
      commentText.value = '';
      commentFocusNode.unfocus();
    } catch (e) {
      debugPrint('⚠️ Error submitting comment: $e');
      Get.snackbar('잠깐!', '댓글 등록에 실패했어요 🐾');
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> submitInlineEdit() async {
    final commentId = editingCommentId.value;
    if (commentId == null) return;

    final content = inlineEditController.text.trim();
    if (content.isEmpty) return;

    isSubmittingInlineEdit.value = true;
    try {
      await _repository.updateComment(post.id, commentId, content);

      // Update local list for instant UI feedback
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final old = comments[index];
        comments[index] = CommunityComment(
          id: old.id,
          authorUid: old.authorUid,
          authorNickname: old.authorNickname,
          content: content,
          createdAt: DateTime.now(),
          isEdited: true,
        );
        comments.refresh();
      }

      cancelEditingComment();
    } catch (e) {
      debugPrint('⚠️ Error updating comment: $e');
      Get.snackbar('잠깐!', '댓글 수정에 실패했어요 🐾');
    } finally {
      isSubmittingInlineEdit.value = false;
    }
  }

  void startEditingReply(String commentId, dynamic reply) {
    cancelEditingComment(); // 댓글 수정 중이면 취소
    editingReplyId.value = reply.id;
    editingReplyCommentId.value = commentId;
    inlineReplyEditController.text = reply.content;
  }

  void cancelEditingReply() {
    editingReplyId.value = null;
    editingReplyCommentId.value = null;
    inlineReplyEditController.clear();
  }

  Future<void> submitReplyEdit() async {
    final replyId = editingReplyId.value;
    final commentId = editingReplyCommentId.value;
    if (replyId == null || commentId == null) return;
    
    final content = inlineReplyEditController.text.trim();
    if (content.isEmpty) return;
    
    isSubmittingInlineEdit.value = true;
    try {
      await _repository.updateReply(post.id, commentId, replyId, content);
      cancelEditingReply();
    } catch (e) {
      debugPrint('⚠️ Error updating reply: $e');
      Get.snackbar('잠깐!', '답글 수정에 실패했어요 🐾');
    } finally {
      isSubmittingInlineEdit.value = false;
    }
  }

  void deleteComment(String commentId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '댓글 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _repository.deleteComment(post.id, commentId);
              } catch (e) {
                debugPrint('⚠️ Error deleting comment: $e');
                Get.snackbar('잠깐!', '댓글 삭제에 실패했어요 🐾');
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void deleteReply(String commentId, String replyId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '답글 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('이 답글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _repository.deleteReply(post.id, commentId, replyId);
              } catch (e) {
                debugPrint('⚠️ Error deleting reply: $e');
                Get.snackbar('잠깐!', '답글 삭제에 실패했어요 🐾');
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> reportComment(String commentId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '댓글 신고',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('이 댓글을 신고하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // close dialog
              try {
                await _repository.reportComment(post.id, commentId, uid);
                Get.snackbar('알림', '신고가 접수되었습니다.');
              } catch (e) {
                debugPrint('⚠️ Error reporting comment: $e');
                if (!e.toString().contains('already reported')) {
                  Get.snackbar('잠깐!', '신고 접수에 실패했어요. 다시 시도해주세요 🐾');
                }
              }
            },
            child: const Text(
              '신고',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void showDeleteConfirmDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '게시글 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('정말로 이 게시글을 삭제하시겠습니까?\n삭제된 글은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          Obx(() {
            return TextButton(
              onPressed: isDeleting.value ? null : () => deletePost(),
              child: isDeleting.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '삭제',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            );
          }),
        ],
      ),
    );
  }

  // ── 차단 필터링 헬퍼 ──────────────────────────────────────────

  /// 현재 사용자의 차단 목록 가져오기
  List<String> get _blockedUsers {
    if (!Get.isRegistered<AuthController>()) return const [];
    return Get.find<AuthController>().blockedUsers.toList();
  }

  /// 댓글 리스트에서 차단된 사용자가 쓴 댓글 제거
  List<CommunityComment> _filterBlockedComments(List<CommunityComment> list) {
    final blocked = _blockedUsers;
    if (blocked.isEmpty) return list;
    return list.where((c) => !blocked.contains(c.authorUid)).toList();
  }

  /// 답글 리스트에서 차단된 사용자가 쓴 답글 제거
  List<CommentReply> _filterBlockedReplies(List<CommentReply> list) {
    final blocked = _blockedUsers;
    if (blocked.isEmpty) return list;
    return list.where((r) => !blocked.contains(r.authorUid)).toList();
  }

  /// 차단 목록이 변경됐을 때 현재 화면의 댓글/답글을 다시 필터링
  void _refilterCommentsAndReplies() {
    final blocked = _blockedUsers;
    if (blocked.isEmpty) return;

    // 현재 댓글 중 차단된 사용자 것 제거
    comments.value =
        comments.where((c) => !blocked.contains(c.authorUid)).toList();

    // 답글도 필터링
    final newReplies = <String, List<CommentReply>>{};
    commentReplies.forEach((commentId, replies) {
      newReplies[commentId] =
          replies.where((r) => !blocked.contains(r.authorUid)).toList();
    });
    commentReplies.assignAll(newReplies);

    // 댓글 카운트 재계산
    int total = comments.length;
    for (final repliesList in commentReplies.values) {
      total += repliesList.length;
    }
    commentCount.value = total;
  }
}
