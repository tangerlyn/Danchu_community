import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import '../../data/repositories/friends_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../core/utils/custom_center_toast.dart';
import '../../data/repositories/meetup_chat_repository.dart';
import '../../services/fcm_service.dart';
import 'package:intl/intl.dart';
import '../history/walk_model.dart';

class DirectChatController extends GetxController {
  final FriendsRepository _repository = FriendsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final MeetupChatRepository _mediaRepository = MeetupChatRepository();
  final ImagePicker _picker = ImagePicker();

  final String chatId;
  final String friendUid;
  final String friendNickname;
  final String friendProfileImageUrl;

  DirectChatController({
    required this.chatId,
    required this.friendUid,
    required this.friendNickname,
    required this.friendProfileImageUrl,
  });

  String? _myUid;
  String? _myNickname;
  String? _myProfileImageUrl;

  final messages = <ChatMessage>[].obs;
  final isLoadingMessages = true.obs;
  final isSubmitting = false.obs;
  final messageText = ''.obs;
  final messageTextController = TextEditingController();
  final scrollController = ScrollController();

  // Optimistic UI — 업로드 중 메시지
  final uploadingMessages = <_UploadingMessage>[].obs;

  @override
  void onInit() {
    super.onInit();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _loadMyInfo();
    _initChatStream(); // async지만 fire-and-forget OK
    _markAsRead();
  }

  @override
  void onClose() {
    messageTextController.dispose();
    scrollController.dispose();
    _markAsRead();
    VideoCompress.deleteAllCache();
    super.onClose();
  }

  Future<void> _loadMyInfo() async {
    if (_myUid == null) return;
    final profile = await _profileRepository.getUserProfile(_myUid!);
    _myNickname = profile?.nickname ?? '알 수 없음';
    _myProfileImageUrl = profile?.profileImageUrl ?? '';
  }

  Future<void> _initChatStream() async {
    // 친구 추가 시점 먼저 가져오기
    DateTime? joinedAt;
    if (_myUid != null) {
      joinedAt = await _repository.getFriendJoinedAt(
        myUid: _myUid!,
        friendUid: friendUid,
      );
      debugPrint('🗓️ [DirectChat] Friend joinedAt: $joinedAt');
    }

    _repository.getDirectMessagesStream(chatId, joinedAt: joinedAt).listen((data) {
      messages.value = data.map((d) => _mapToMessage(d)).toList();
      isLoadingMessages.value = false;
      _markAsRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
  }

  ChatMessage _mapToMessage(Map<String, dynamic> data) {
    // walkRoutePoints 파싱
    final walkRoutePoints = (data['walkRoutePoints'] as List?)
        ?.map((p) => Map<String, double>.from(
            (p as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))
        .toList();

    return ChatMessage(
      id: data['id'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderNickname: data['senderNickname'] ?? '',
      message: data['message'] ?? '',
      imageUrl: data['imageUrl'],
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      videoUrl: data['videoUrl'],
      videoThumbnailUrl: data['videoThumbnailUrl'],
      type: data['type'] ?? 'normal',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      readBy: data['readBy'] != null
          ? List<String>.from(data['readBy'])
          : [],
      walkRoutePoints: walkRoutePoints,
      walkDate: data['walkDate'],
      walkDogNames: data['walkDogNames'],
    );
  }

  void _markAsRead() {
    if (_myUid == null) return;
    _repository.markDirectMessagesAsRead(
      chatId: chatId,
      myUid: _myUid!,
    );
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  // ── 텍스트 메시지 전송 ──
  Future<void> sendMessage() async {
    final content = messageText.value.trim();
    if (content.isEmpty || _myUid == null) return;

    isSubmitting.value = true;
    try {
      final msgId = _repository.getNewMessageId(chatId);
      await _repository.sendDirectMessage(
        chatId: chatId,
        messageData: {
          'id': msgId,
          'senderUid': _myUid!,
          'senderNickname': _myNickname ?? '알 수 없음',
          'message': content,
          'imageUrls': [],
          'readBy': [_myUid!],
        },
      );
      messageTextController.clear();
      messageText.value = '';

      // 상대방에게 채팅 알림
      FcmService.sendDirectChatNotification(
        toUid: friendUid,
        senderNickname: _myNickname ?? '알 수 없음',
        message: content,
        currentUid: _myUid!,
      );
    } catch (e) {
      debugPrint('⚠️ [DirectChat] sendMessage error: $e');
      Get.snackbar('잠깐!', '메시지 전송에 실패했어요 🐾');
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── 산책 공유 ──
  Future<void> sendWalkRecord(Walk walk) async {
    if (_myUid == null) return;

    isSubmitting.value = true;
    try {
      final msgId = _repository.getNewMessageId(chatId);
      final String dateStr = DateFormat('yyyy년 M월 d일', 'ko_KR').format(walk.startTime);
      final String? dogsStr = walk.dogNameList.isNotEmpty ? walk.dogNameList.join(', ') : null;

      await _repository.sendDirectMessage(
        chatId: chatId,
        messageData: {
          'id': msgId,
          'senderUid': _myUid!,
          'senderNickname': _myNickname ?? '알 수 없음',
          'message': '산책 기록을 공유했습니다.',
          'type': 'walk',
          'walkRoutePoints': walk.decodedRoutePoints.map((p) => {'lat': p[0], 'lng': p[1]}).toList(),
          'walkDate': dateStr,
          if (dogsStr != null) 'walkDogNames': dogsStr,
          'imageUrls': [],
          'readBy': [_myUid!],
        },
      );

      FcmService.sendDirectChatNotification(
        toUid: friendUid,
        senderNickname: _myNickname ?? '알 수 없음',
        message: '산책 기록을 공유했습니다.',
        currentUid: _myUid!,
      );
    } catch (e) {
      debugPrint('⚠️ [DirectChat] sendWalkRecord error: $e');
      Get.snackbar('잠깐!', '산책 기록 공유에 실패했어요 🐾');
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── 이미지 전송 ──
  Future<void> pickAndSendImage(ImageSource source) async {
    if (_myUid == null) return;
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
          await _processAndSendSingleImage(File(pickedFiles.first.path));
        } else {
          await _processAndSendMultipleImages(
              pickedFiles.map((f) => File(f.path)).toList());
        }
        isSubmitting.value = false;
      } else {
        final pickedFile = await _picker.pickImage(
            source: source, imageQuality: 70);
        if (pickedFile == null) return;
        isSubmitting.value = true;
        await _processAndSendSingleImage(File(pickedFile.path));
        isSubmitting.value = false;
      }
    } catch (e) {
      debugPrint('⚠️ [DirectChat] pickAndSendImage error: $e');
      Get.snackbar('잠깐!', '사진을 불러오는 중 문제가 발생했어요 🐾');
      isSubmitting.value = false;
    }
  }

  Future<void> _processAndSendSingleImage(File file) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = _UploadingMessage(
        id: tempId, localImagePath: file.path, createdAt: DateTime.now());
    uploadingMessages.add(tempMsg);
    try {
      // MeetupChatRepository의 uploadImage 재사용 (chat_images 폴더)
      final imageUrl = await _mediaRepository.uploadImage(chatId, _myUid!, file);
      uploadingMessages.removeWhere((m) => m.id == tempId);

      final msgId = _repository.getNewMessageId(chatId);
      await _repository.sendDirectMessage(
        chatId: chatId,
        messageData: {
          'id': msgId,
          'senderUid': _myUid!,
          'senderNickname': _myNickname ?? '알 수 없음',
          'message': '사진을 보냈습니다.',
          'imageUrl': imageUrl,
          'imageUrls': [],
          'readBy': [_myUid!],
        },
      );

      FcmService.sendDirectChatNotification(
        toUid: friendUid,
        senderNickname: _myNickname ?? '알 수 없음',
        message: '사진을 보냈습니다.',
        currentUid: _myUid!,
      );
    } catch (e) {
      uploadingMessages.removeWhere((m) => m.id == tempId);
      debugPrint('⚠️ [DirectChat] _processAndSendSingleImage error: $e');
      Get.snackbar('잠깐!', '사진 전송에 실패했어요 🐾');
    }
  }

  Future<void> _processAndSendMultipleImages(List<File> files) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMsg = _UploadingMessage(
        id: tempId,
        localImagePaths: files.map((f) => f.path).toList(),
        createdAt: DateTime.now());
    uploadingMessages.add(tempMsg);
    try {
      final List<String> uploadedUrls = [];
      for (final file in files) {
        final imageUrl = await _mediaRepository.uploadImage(chatId, _myUid!, file);
        uploadedUrls.add(imageUrl);
      }
      uploadingMessages.removeWhere((m) => m.id == tempId);

      final msgId = _repository.getNewMessageId(chatId);
      await _repository.sendDirectMessage(
        chatId: chatId,
        messageData: {
          'id': msgId,
          'senderUid': _myUid!,
          'senderNickname': _myNickname ?? '알 수 없음',
          'message': '사진을 보냈습니다.',
          'imageUrls': uploadedUrls,
          'readBy': [_myUid!],
        },
      );

      FcmService.sendDirectChatNotification(
        toUid: friendUid,
        senderNickname: _myNickname ?? '알 수 없음',
        message: '사진을 보냈습니다.',
        currentUid: _myUid!,
      );
    } catch (e) {
      uploadingMessages.removeWhere((m) => m.id == tempId);
      debugPrint('⚠️ [DirectChat] _processAndSendMultipleImages error: $e');
      Get.snackbar('잠깐!', '사진 전송에 실패했어요 🐾');
    }
  }

  // ── 동영상 전송 ──
  Future<void> pickAndSendVideo(ImageSource source) async {
    if (_myUid == null) return;
    try {
      final pickedFile = await _picker.pickVideo(
          source: source, maxDuration: const Duration(seconds: 30));
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final mediaInfo = await VideoCompress.getMediaInfo(file.path);
      final durationSec = (mediaInfo.duration ?? 0) / 1000;
      if (durationSec > 30) {
        CustomCenterToast.show('동영상은 최대 30초까지 전송할 수 있습니다.');
        return;
      }

      isSubmitting.value = true;

      // 썸네일 먼저 생성
      String? localThumbPath;
      try {
        final thumbFile = await VideoCompress.getFileThumbnail(
            file.path, quality: 50, position: -1);
        localThumbPath = thumbFile.path;
      } catch (_) {}

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      uploadingMessages.add(_UploadingMessage(
        id: tempId,
        localVideoPath: file.path,
        localThumbnailPath: localThumbPath,
        createdAt: DateTime.now(),
        isVideo: true,
      ));

      final result = await _mediaRepository.uploadVideo(chatId, _myUid!, file);
      uploadingMessages.removeWhere((m) => m.id == tempId);

      final msgId = _repository.getNewMessageId(chatId);
      await _repository.sendDirectMessage(
        chatId: chatId,
        messageData: {
          'id': msgId,
          'senderUid': _myUid!,
          'senderNickname': _myNickname ?? '알 수 없음',
          'message': '동영상을 보냈습니다.',
          'videoUrl': result['videoUrl'],
          'videoThumbnailUrl': result['thumbnailUrl'],
          'imageUrls': [],
          'readBy': [_myUid!],
        },
      );

      FcmService.sendDirectChatNotification(
        toUid: friendUid,
        senderNickname: _myNickname ?? '알 수 없음',
        message: '동영상을 보냈습니다.',
        currentUid: _myUid!,
      );
      isSubmitting.value = false;
    } catch (e) {
      uploadingMessages.clear();
      debugPrint('⚠️ [DirectChat] pickAndSendVideo error: $e');
      Get.snackbar('잠깐!', '동영상 전송에 실패했어요 🐾');
      isSubmitting.value = false;
    }
  }

  String? get myUid => _myUid;
}

/// 업로드 중인 임시 메시지 모델
class _UploadingMessage {
  final String id;
  final String? localImagePath;
  final List<String> localImagePaths;
  final String? localVideoPath;
  final String? localThumbnailPath;
  final DateTime createdAt;
  final bool isVideo;

  _UploadingMessage({
    required this.id,
    this.localImagePath,
    this.localImagePaths = const [],
    this.localVideoPath,
    this.localThumbnailPath,
    required this.createdAt,
    this.isVideo = false,
  });
}
