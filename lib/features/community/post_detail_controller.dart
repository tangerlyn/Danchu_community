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
import '../../services/fcm_service.dart';
import 'community_controller.dart';

class PostDetailController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  final ProfileRepository _profileRepository = ProfileRepository();
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

  // Deleted user tracking
  var isDeletedAuthor = false.obs;
  var deletedCommentAuthors = <String>{}.obs;

  var comments = <CommunityComment>[].obs;
  
  final commentTextController = TextEditingController();
  late FocusNode commentFocusNode;
  final inlineEditController = TextEditingController();
  late FocusNode inlineEditFocusNode;
  var isSubmittingComment = false.obs;
  var isSubmittingInlineEdit = false.obs;
  var commentText = ''.obs; // Reactive text for send button state
  
  var editingCommentId = RxnString();
  
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
    inlineEditFocusNode = FocusNode();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _initializePostData(post);

    if (post.mainCategory == '모임') {
      _repository.getMeetupParticipantsStream(post.id).listen((data) {
        meetupParticipants.value = data;
        currentParticipantCount.value = data.length;
      });
    }

    // Record view (deduplicated)
    _recordView();

    // Check if post author is a deleted user
    _checkDeletedAuthor();

    // 댓글 스트림 구독
    _repository.getCommentsStream(post.id).listen((data) {
      comments.value = data;
      
      // 각 댓글의 대댓글 스트림 구독
      for (var comment in data) {
        _repository.getRepliesStream(post.id, comment.id).listen((replies) {
          commentReplies[comment.id] = replies;
          commentReplies.refresh();
          
          // 총 댓글 수 = 댓글 수 + 모든 답글 수 합산
          int total = comments.length;
          for (final repliesList in commentReplies.values) {
            total += repliesList.length;
          }
          commentCount.value = total;
        });
      }
      
      // 댓글만 있고 답글 없을 때도 업데이트
      int total = data.length;
      for (final repliesList in commentReplies.values) {
        total += repliesList.length;
      }
      commentCount.value = total;

      // 삭제된 댓글 작성자 체크
      _checkDeletedCommentAuthors(data);
    });
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

  Future<void> _checkDeletedCommentAuthors(List<CommunityComment> commentList) async {
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
      Get.snackbar('오류', '삭제에 실패했습니다: $e');
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
        title: const Text('게시글 신고', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Get.snackbar('오류', '신고 처리에 실패했습니다: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            child: const Text('신고', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
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
      Get.snackbar('오류', '좋아요 처리에 실패했습니다: $e');
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
          currentUid: uid,
        );
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
      Get.snackbar('오류', e.toString().contains('마감') ? '모임 인원이 마감되었습니다.' : '처리 중 오류가 발생했습니다.');
    }
  }

  void startEditingComment(CommunityComment comment) {
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
        // Submit Reply
        final newReply = CommentReply(
          id: _repository.getNewDocId(),
          authorUid: user.uid,
          authorNickname: nickname,
          authorProfileImageUrl: userProfile?.profileImageUrl,
          content: content,
          createdAt: DateTime.now(),
        );
        await _repository.addReply(post.id, replyingToCommentId.value!, newReply);

        // Notify Comment Author
        final commentId = replyingToCommentId.value!;
        final parentComment = comments.firstWhereOrNull((c) => c.id == commentId);
        if (parentComment != null) {
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
              currentUid: user.uid,
            );
          }
        }

        // Notify other participants in the same thread
        final otherRepliers = commentReplies[commentId]
            ?.map((r) => r.authorUid)
            .where((uid) => uid != user.uid && uid != parentComment?.authorUid)
            .toSet()
            .toList() ?? [];
        
        if (otherRepliers.isNotEmpty) {
          FcmService.sendThreadReplyNotification(
            notifyUids: otherRepliers,
            replierNickname: nickname,
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
          currentUid: user.uid,
        );
      }
      
      commentTextController.clear();
      commentText.value = '';
      commentFocusNode.unfocus();
    } catch (e) {
      Get.snackbar('오류', '등록 중 오류가 발생했습니다: $e');
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
      Get.snackbar('오류', '댓글 수정 중 오류가 발생했습니다: $e');
    } finally {
      isSubmittingInlineEdit.value = false;
    }
  }

  void deleteComment(String commentId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('댓글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Get.snackbar('오류', '댓글 삭제에 실패했습니다: $e');
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  void deleteReply(String commentId, String replyId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('답글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Get.snackbar('오류', '답글 삭제에 실패했습니다: $e');
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
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
        title: const Text('댓글 신고', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Get.snackbar('오류', '신고 처리에 실패했습니다: ${e.toString().replaceAll('Exception: ', '')}');
              }
            },
            child: const Text('신고', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }


  void showDeleteConfirmDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('게시글 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            );
          }),
        ],
      ),
    );
  }
}
