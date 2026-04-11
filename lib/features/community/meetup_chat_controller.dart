import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/meetup_chat_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../core/utils/custom_center_toast.dart';
import '../../core/app_colors.dart';
import '../../services/fcm_service.dart';
import '../../data/repositories/community_repository_impl.dart';
import 'community_controller.dart';

class MeetupChatController extends GetxController {
  final MeetupChatRepository _chatRepository = MeetupChatRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  var isLeaving = false.obs;

  final String postId;
  final String postTitle;

  MeetupChatController({required this.postId, required this.postTitle});

  final failedMessages = <ChatMessage>[].obs;
  var isLoadingMessages = true.obs;
  final userProfileImages = <String, String?>{}.obs;

  final messages = <ChatMessage>[].obs;
  final messageTextController = TextEditingController();
  final messageText = ''.obs;
  final isSubmitting = false.obs;
  final scrollController = ScrollController();
  final isChatMuted = false.obs;
  final chatRoomName = ''.obs;
  final chatRoomImageUrl = ''.obs;
  final participantCount = 0.obs;

  var hostUid = RxnString();
  var joinType = 'free'.obs;
  var pendingRequestCount = 0.obs;

  String? _currentUid;
  String? _currentNickname;

  String? get currentUid => _currentUid;

  @override
  void onInit() {
    super.onInit();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _fetchUserInfo();
    _loadMuteStatus();
    _loadChatRoomName();
    _listenParticipantCount();

    if (_currentUid != null) {
      _initChatStream();
      _listenPendingRequests();
    }
  }

  Future<void> _initChatStream() async {
    await _chatRepository.updateLastReadAt(postId, _currentUid!);
    final joinedAt = await _chatRepository.getParticipantJoinedAt(
      postId,
      _currentUid!,
    );

    // ✅ 채팅방 진입 시 참가자 프로필 미리 로드
    await _preloadParticipantProfiles();

    _chatRepository.getMessagesStream(postId, joinedAt: joinedAt).listen((
      data,
    ) {
      messages.value = data;
      isLoadingMessages.value = false;

      if (_currentUid != null) {
        _chatRepository.updateLastReadAt(postId, _currentUid!);
      }

      final senderUids = data.map((m) => m.senderUid).toSet();
      for (final uid in senderUids) {
        if (uid != _currentUid && !userProfileImages.containsKey(uid)) {
          userProfileImages[uid] = null;
          _profileRepository.getUserProfile(uid).then((profile) {
            userProfileImages[uid] = profile?.profileImageUrl ?? '';
          });
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  // ✅ 새로 추가할 함수
  Future<void> _preloadParticipantProfiles() async {
    try {
      final participantsSnap = await FirebaseFirestore.instance
          .collection('community_posts')
          .doc(postId)
          .collection('participants')
          .get();

      for (final doc in participantsSnap.docs) {
        final uid = doc.id;
        final profile = await _profileRepository.getUserProfile(uid);
        // null 플레이스홀더 없이 바로 실제 값 넣기
        userProfileImages[uid] = profile?.profileImageUrl ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ preloadParticipantProfiles error: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    if (_currentUid != null) {
      final profile = await _profileRepository.getUserProfile(_currentUid!);
      _currentNickname = profile?.nickname ?? '알 수 없음';
      userProfileImages[_currentUid!] = profile?.profileImageUrl ?? '';
    }
  }

  Future<void> _loadMuteStatus() async {
    if (_currentUid != null) {
      isChatMuted.value = await _chatRepository.getChatMuted(
        postId,
        _currentUid!,
      );
    }
  }

  Future<void> _loadChatRoomName() async {
    try {
      final doc = await _firestore
          .collection('community_posts')
          .doc(postId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final name = data?['chatRoomName'] as String?;
        chatRoomName.value = name ?? postTitle;
        chatRoomImageUrl.value = data?['chatRoomImageUrl'] as String? ?? '';
        hostUid.value = data?['hostUid'] as String?;
        joinType.value = data?['joinType'] as String? ?? 'free';
      } else {
        chatRoomName.value = postTitle;
        chatRoomImageUrl.value = '';
        hostUid.value = null;
        joinType.value = 'free';
      }
    } catch (e) {
      chatRoomName.value = postTitle;
      chatRoomImageUrl.value = '';
      hostUid.value = null;
      joinType.value = 'free';
    }
  }

  void _listenPendingRequests() {
    if (postId.isEmpty) return;

    _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('join_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          pendingRequestCount.value = snapshot.docs.length;
        });
  }

  bool get isHost => _currentUid != null && _currentUid == hostUid.value;

  void _listenParticipantCount() {
    _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
          participantCount.value = snapshot.docs.length;
        });
  }

  Future<List<Map<String, dynamic>>> getParticipantsInfo() async {
    final List<Map<String, dynamic>> info = [];
    try {
      final snap = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('participants')
          .get();

      for (var doc in snap.docs) {
        final uid = doc.id;
        final profile = await _profileRepository.getUserProfile(uid);
        info.add({
          'uid': uid,
          'nickname': profile?.nickname ?? '알 수 없음',
          'profileImageUrl': profile?.profileImageUrl,
        });
      }
    } catch (e) {
      debugPrint('Error fetching participants info: $e');
    }
    return info;
  }

  Future<void> changeHost(String newHostUid, String newHostNickname) async {
    if (_currentUid == null) return;

    try {
      final repo = CommunityRepositoryImpl();
      await repo.changeHost(postId, newHostUid);
      hostUid.value = newHostUid;
      await _chatRepository.sendSystemMessage(
        postId,
        '${newHostNickname}님으로 단장이 변경되었습니다.',
      );
      Get.snackbar('알림', '단장이 ${newHostNickname}님으로 변경되었습니다.');
    } catch (e) {
      debugPrint('Error changing host: $e');
      Get.snackbar('오류', '단장 변경 중 문제가 발생했습니다.');
    }
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  Future<void> sendMessage() async {
    final content = messageText.value.trim();
    if (content.isEmpty || _currentUid == null) return;

    isSubmitting.value = true;
    final msgId = _chatRepository.getNewMessageId(postId);
    final message = ChatMessage(
      id: msgId,
      senderUid: _currentUid!,
      senderNickname: _currentNickname ?? '알 수 없음',
      message: content,
      createdAt: DateTime.now(),
      readBy: [_currentUid!],
    );

    try {
      await _chatRepository.sendMessage(postId, message);

      // Notify Chat Participants
      _notifyChatParticipants(content);

      messageTextController.clear();
      messageText.value = '';
    } catch (e) {
      debugPrint('⚠️ Error sending message: $e');
      failedMessages.insert(0, message);
      Get.snackbar('잠깐!', '메시지 전송에 실패했어요 🐾');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> resendMessage(ChatMessage message) async {
    isSubmitting.value = true;
    try {
      await _chatRepository.sendMessage(postId, message);
      failedMessages.remove(message);
    } catch (e) {
      debugPrint('⚠️ Error resending message: $e');
      Get.snackbar('잠깐!', '메시지 전송에 실패했어요 🐾');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    if (_currentUid == null) return;
    try {
      if (source == ImageSource.gallery) {
        final pickedFiles = await _picker.pickMultiImage(
          imageQuality: 70,
          limit: 5,
        );
        if (pickedFiles.isEmpty) return;
        if (pickedFiles.length > 5) {
          CustomCenterToast.show('최대 5장까지 선택 가능합니다.');
          return;
        }

        isSubmitting.value = true;

        if (pickedFiles.length == 1) {
          // 1장이면 기존 방식
          await _processAndSendSingleImage(File(pickedFiles.first.path));
        } else {
          // 여러 장이면 한 메시지로 묶어서 전송
          await _processAndSendMultipleImages(
            pickedFiles.map((f) => File(f.path)).toList(),
          );
        }

        isSubmitting.value = false;
      } else {
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70,
        );
        if (pickedFile == null) return;

        isSubmitting.value = true;
        await _processAndSendSingleImage(File(pickedFile.path));
        isSubmitting.value = false;
      }
    } catch (e) {
      debugPrint('⚠️ Error picking images: $e');
      Get.snackbar('잠깐!', '사진을 불러오는 중 문제가 발생했어요 🐾');
      isSubmitting.value = false;
    }
  }

  Future<void> _processAndSendSingleImage(File file) async {
    try {
      final imageUrl = await _chatRepository.uploadImage(
        postId,
        _currentUid!,
        file,
      );

      final msgId = _chatRepository.getNewMessageId(postId);
      final message = ChatMessage(
        id: msgId,
        senderUid: _currentUid!,
        senderNickname: _currentNickname ?? '알 수 없음',
        message: '사진을 보냈습니다.',
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        readBy: [_currentUid!],
      );

      try {
        await _chatRepository.sendMessage(postId, message);

        // Notify Chat Participants
        _notifyChatParticipants('사진을 보냈습니다.');
      } catch (e) {
        debugPrint('⚠️ Error sending image message: $e');
        failedMessages.insert(0, message);
        Get.snackbar('잠깐!', '사진 전송에 실패했어요 🐾');
      }
    } catch (e) {
      debugPrint('⚠️ Error uploading image: $e');
      Get.snackbar('잠깐!', '사진 업로드에 실패했어요 🐾');
    }
  }

  Future<void> _processAndSendMultipleImages(List<File> files) async {
    try {
      final List<String> uploadedUrls = [];
      for (final file in files) {
        final imageUrl = await _chatRepository.uploadImage(
          postId,
          _currentUid!,
          file,
        );
        uploadedUrls.add(imageUrl);
      }

      final msgId = _chatRepository.getNewMessageId(postId);
      final message = ChatMessage(
        id: msgId,
        senderUid: _currentUid!,
        senderNickname: _currentNickname ?? '알 수 없음',
        message: '사진을 보냈습니다.',
        imageUrls: uploadedUrls,
        createdAt: DateTime.now(),
        readBy: [_currentUid!],
      );

      try {
        await _chatRepository.sendMessage(postId, message);
        _notifyChatParticipants('사진을 보냈습니다.');
      } catch (e) {
        debugPrint('⚠️ Error sending multi-image message: $e');
        failedMessages.insert(0, message);
        Get.snackbar('잠깐!', '사진 전송에 실패했어요 🐾');
      }
    } catch (e) {
      debugPrint('⚠️ Error uploading multi-images: $e');
      Get.snackbar('잠깐!', '사진 업로드에 실패했어요 🐾');
    }
  }

  Future<void> toggleChatMute() async {
    if (_currentUid == null) return;
    try {
      await _chatRepository.toggleChatMuted(postId, _currentUid!);
      isChatMuted.value = !isChatMuted.value;
    } catch (e) {
      debugPrint('⚠️ Error toggling chat mute: $e');
      Get.snackbar('잠깐!', '설정 변경에 실패했어요 🐾');
    }
  }

  /// Rename the chat room
  Future<void> renameChatRoom(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    try {
      await _firestore.collection('community_posts').doc(postId).update({
        'chatRoomName': trimmed,
      });
      chatRoomName.value = trimmed;
    } catch (e) {
      debugPrint('⚠️ Error renaming chat room: $e');
      Get.snackbar('잠깐!', '이름 변경에 실패했어요 🐾');
    }
  }

  /// Leave chat room — works for both author and participants
  Future<void> leaveChatRoom() async {
    if (_currentUid == null || isLeaving.value) return;

    isLeaving.value = true;
    try {
      final postRef = _firestore.collection('community_posts').doc(postId);
      final participantRef = postRef
          .collection('participants')
          .doc(_currentUid!);

      // First, check current participant count OUTSIDE the transaction
      final participantsSnapshot = await postRef
          .collection('participants')
          .get();
      final actualCount = participantsSnapshot.docs.length;
      final shouldDeletePost = actualCount <= 1;

      if (!shouldDeletePost && _currentNickname != null) {
        await _chatRepository.sendSystemMessage(
          postId,
          '${_currentNickname}님이 나갔습니다.',
        );
      }

      // Remove self from participants
      final participantDoc = await participantRef.get();
      if (participantDoc.exists) {
        await participantRef.delete();

        // Remove from joined_chats
        if (_currentUid != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('joined_chats')
                .doc(postId)
                .delete();
          } catch (_) {}
        }

        // Update participant count (only if not deleting)
        if (!shouldDeletePost) {
          try {
            await postRef.update({
              'currentParticipantCount': FieldValue.increment(-1),
            });
          } catch (_) {}
        }
      }

      // If is host and not deleting, transfer host to someone else
      if (isHost && !shouldDeletePost) {
        final remainingParticipants = participantsSnapshot.docs
            .where((p) => p.id != _currentUid)
            .toList();
        if (remainingParticipants.isNotEmpty) {
          await CommunityRepositoryImpl().changeHost(
            postId,
            remainingParticipants.first.id,
          );
        }
      }

      // Refresh badge in CommunityController
      if (Get.isRegistered<CommunityController>()) {
        Get.find<CommunityController>().cancelUnreadSubscription(postId);
        Get.find<CommunityController>().refreshMyMeetupPostIds();
      }

      // Navigate: if post deleted, go all the way back; otherwise just pop dialog and chat page (2 routes)
      if (shouldDeletePost) {
        Get.until((route) => route.isFirst);
      } else {
        Get.close(2);
      }
    } catch (e) {
      isLeaving.value = false;
      debugPrint('⚠️ Error leaving chat room: $e');
      Get.snackbar('잠깐!', '채팅방 나가기에 실패했어요 🐾');
    }
  }

  /// Delete post document and all subcollections with proper error handling
  Future<void> _deletePostAndSubcollections(DocumentReference postRef) async {
    // 1. Cleanup joined_chats for all participants before deleting the subcollection
    try {
      final snap = await postRef.collection('participants').get();
      for (var doc in snap.docs) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .collection('joined_chats')
              .doc(postRef.id)
              .delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Warning: Could not cleanup joined_chats: $e');
    }

    // Helper to safely delete a subcollection
    Future<void> safeDeleteCollection(String name) async {
      try {
        final snap = await postRef.collection(name).get();
        for (var doc in snap.docs) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Warning: Could not delete subcollection $name: $e');
      }
    }

    // Delete all known subcollections
    await safeDeleteCollection('comments');
    await safeDeleteCollection('participants');
    await safeDeleteCollection('chat');
    await safeDeleteCollection('chat_read');

    // Delete the post document itself
    try {
      await postRef.delete();
    } catch (e) {
      debugPrint('Warning: Could not delete post document: $e');
    }
  }

  @override
  void onClose() {
    // Update last read on close
    if (_currentUid != null) {
      _chatRepository.updateLastReadAt(postId, _currentUid!);
    }
    messageTextController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> changeChatRoomImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    final croppedFile = await _cropImage(File(pickedFile.path));
    if (croppedFile == null) return;

    isSubmitting.value = true;
    try {
      final String fileName = '${postId}.jpg';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('chat_room_images')
          .child(fileName);

      await ref.putFile(File(croppedFile.path));
      final String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('community_posts').doc(postId).update({
        'chatRoomImageUrl': downloadUrl,
      });

      chatRoomImageUrl.value = downloadUrl;
      Get.snackbar('성공', '채팅방 대표 사진이 변경되었습니다. 🐾');
    } catch (e) {
      debugPrint('⚠️ Error updating chat room image: $e');
      Get.snackbar('잠깐!', '사진 변경에 실패했습니다. 다시 시도해주세요 🐾');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<CroppedFile?> _cropImage(File imageFile) async {
    return await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '이미지 자르기',
          toolbarColor: AppColors.deepBrown,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '이미지 자르기',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cancelButtonTitle: '취소',
          doneButtonTitle: '완료',
          rotateButtonsHidden: true,
          resetButtonHidden: true,
        ),
      ],
    );
  }

  Future<void> _notifyChatParticipants(String content) async {
    try {
      final participantsSnap = await _firestore
          .collection('community_posts')
          .doc(postId)
          .collection('participants')
          .get();

      final participantUids = participantsSnap.docs.map((d) => d.id).toList();

      final List<String> mutedUids = [];
      // Meetups are small (usually < 20), so manual loop is okay for now
      for (final uid in participantUids) {
        if (uid == _currentUid) continue;
        final isMuted = await _chatRepository.getChatMuted(postId, uid);
        if (isMuted) mutedUids.add(uid);
      }

      FcmService.sendChatNotification(
        participantUids: participantUids,
        senderNickname: _currentNickname ?? '알 수 없음',
        message: content,
        postId: postId,
        currentUid: _currentUid!,
        mutedUids: mutedUids,
      );
    } catch (e) {
      debugPrint('⚠️ Chat notification trigger failed: $e');
    }
  }
}
