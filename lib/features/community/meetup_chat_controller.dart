import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/meetup_chat_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../core/utils/custom_center_toast.dart';
import '../../services/fcm_service.dart';
import 'community_controller.dart';

class MeetupChatController extends GetxController {
  final MeetupChatRepository _chatRepository = MeetupChatRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var isLeaving = false.obs;

  final String postId;
  final String postTitle;

  MeetupChatController({required this.postId, required this.postTitle});

  final failedMessages = <ChatMessage>[].obs;
  final userProfileImages = <String, String?>{}.obs;
  
  final messages = <ChatMessage>[].obs;
  final messageTextController = TextEditingController();
  final messageText = ''.obs;
  final isSubmitting = false.obs;
  final scrollController = ScrollController();
  final isChatMuted = false.obs;
  final chatRoomName = ''.obs;
  final participantCount = 0.obs;

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
    }
  }

  Future<void> _initChatStream() async {
    await _chatRepository.updateLastReadAt(postId, _currentUid!);
    final joinedAt = await _chatRepository.getParticipantJoinedAt(postId, _currentUid!);

    // ✅ 채팅방 진입 시 참가자 프로필 미리 로드
    await _preloadParticipantProfiles();

    _chatRepository.getMessagesStream(postId, joinedAt: joinedAt).listen((data) {
      messages.value = data;
      
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
      isChatMuted.value = await _chatRepository.getChatMuted(postId, _currentUid!);
    }
  }

  Future<void> _loadChatRoomName() async {
    try {
      final doc = await _firestore.collection('community_posts').doc(postId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final name = data?['chatRoomName'] as String?;
        chatRoomName.value = name ?? postTitle;
      } else {
        chatRoomName.value = postTitle;
      }
    } catch (e) {
      chatRoomName.value = postTitle;
    }
  }

  void _listenParticipantCount() {
    _firestore
        .collection('community_posts').doc(postId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      participantCount.value = snapshot.docs.length;
    });
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
      failedMessages.insert(0, message);
      Get.snackbar('오류', '메시지 전송에 실패했습니다.');
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
      Get.snackbar('오류', '메시지 재전송에 실패했습니다.');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> pickAndSendImage(ImageSource source) async {
    if (_currentUid == null) return;
    try {
      final picker = ImagePicker();
      
      if (source == ImageSource.gallery) {
        final pickedFiles = await picker.pickMultiImage(imageQuality: 70, limit: 5);
        if (pickedFiles.isEmpty) return;
        if (pickedFiles.length > 5) {
          CustomCenterToast.show('최대 5장까지 선택 가능합니다.');
          return;
        }
        
        isSubmitting.value = true;
        for (final pickedFile in pickedFiles) {
          await _processAndSendSingleImage(File(pickedFile.path));
        }
        isSubmitting.value = false;
      } else {
        final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
        if (pickedFile == null) return;
        
        isSubmitting.value = true;
        await _processAndSendSingleImage(File(pickedFile.path));
        isSubmitting.value = false;
      }
    } catch (e) {
      Get.snackbar('오류', '이미지를 가져오지 못했습니다.');
      isSubmitting.value = false;
    }
  }

  Future<void> _processAndSendSingleImage(File file) async {
    try {
      final imageUrl = await _chatRepository.uploadImage(postId, _currentUid!, file);

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
        failedMessages.insert(0, message);
        Get.snackbar('오류', '이미지 전송에 실패했습니다.');
      }
    } catch (e) {
      Get.snackbar('오류', '이미지 업로드에 실패했습니다.');
    }
  }

  Future<void> toggleChatMute() async {
    if (_currentUid == null) return;
    try {
      await _chatRepository.toggleChatMuted(postId, _currentUid!);
      isChatMuted.value = !isChatMuted.value;
    } catch (e) {
      Get.snackbar('오류', '알림 설정 변경에 실패했습니다.');
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
      Get.snackbar('오류', '채팅방 이름 변경에 실패했습니다.');
    }
  }

  /// Leave chat room — works for both author and participants
  Future<void> leaveChatRoom() async {
    if (_currentUid == null || isLeaving.value) return;
    
    isLeaving.value = true;
    try {
      final postRef = _firestore.collection('community_posts').doc(postId);
      final participantRef = postRef.collection('participants').doc(_currentUid!);

      // First, check current participant count OUTSIDE the transaction
      final participantsSnapshot = await postRef.collection('participants').get();
      final actualCount = participantsSnapshot.docs.length;
      final shouldDeletePost = actualCount <= 1;

      // Remove self from participants
      final participantDoc = await participantRef.get();
      if (participantDoc.exists) {
        await participantRef.delete();
        
        // Remove from joined_chats
        if (_currentUid != null) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(_currentUid).collection('joined_chats').doc(postId).delete();
          } catch (_) {}
        }

        // Update participant count (only if not deleting)
        if (!shouldDeletePost) {
          try {
            await postRef.update({'currentParticipantCount': FieldValue.increment(-1)});
          } catch (_) {}
        }
      }
      
      // If last participant, delete the entire post and subcollections
      if (shouldDeletePost) {
        await _deletePostAndSubcollections(postRef);
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
      debugPrint('Error leaving chat room: $e');
      Get.snackbar('오류', '채팅방 나가기에 실패했습니다.');
    }
  }

  /// Delete post document and all subcollections with proper error handling
  Future<void> _deletePostAndSubcollections(DocumentReference postRef) async {
    // 1. Cleanup joined_chats for all participants before deleting the subcollection
    try {
      final snap = await postRef.collection('participants').get();
      for (var doc in snap.docs) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(doc.id).collection('joined_chats').doc(postRef.id).delete();
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
        currentUid: _currentUid!,
        mutedUids: mutedUids,
      );
    } catch (e) {
      debugPrint('⚠️ Chat notification trigger failed: $e');
    }
  }
}
