import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/models/user_profile.dart';

class ChatController extends GetxController {
  final ChatRepository _repository = ChatRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  
  final RxList<QueryDocumentSnapshot> myRooms = <QueryDocumentSnapshot>[].obs;
  final RxList<QueryDocumentSnapshot> messages = <QueryDocumentSnapshot>[].obs;
  final RxMap<String, UserProfile> userProfiles = <String, UserProfile>{}.obs;
  
  ScrollController? scrollController;
  
  // Test bot
  final RxBool isBotRunning = false.obs;
  Timer? _botTimer;
  
  StreamSubscription? _roomsStream;
  StreamSubscription? _messagesStream;

  // Use fallback for unauthenticated testing
  String get myUid => FirebaseAuth.instance.currentUser?.uid ?? 'test_user_1';

  @override
  void onInit() {
    super.onInit();
    _listenToMyRooms();
  }

  @override
  void onClose() {
    _roomsStream?.cancel();
    _messagesStream?.cancel();
    _botTimer?.cancel();
    scrollController?.dispose();
    super.onClose();
  }

  // ─── Uses myUid getter (works even without auth) ───
  void _listenToMyRooms() {
    final uid = myUid;
    debugPrint('📋 Listening to rooms for uid: $uid');
    
    _roomsStream = _repository.getMyRooms(uid).listen(
      (snapshot) async {
        debugPrint('📋 Rooms update: ${snapshot.docs.length} rooms');
        myRooms.value = snapshot.docs;
        
        final Set<String> uidsToFetch = {};
        
        for (var doc in snapshot.docs) {
          final members = List<String>.from(doc['members'] ?? []);
          final otherUid = members.firstWhere((id) => id != uid, orElse: () => '');
          if (otherUid.isNotEmpty && !userProfiles.containsKey(otherUid)) {
             uidsToFetch.add(otherUid);
          }
        }
        
        if (uidsToFetch.isNotEmpty) {
           for (var targetUid in uidsToFetch) {
              final profile = await _profileRepository.getUserProfile(targetUid);
              if (profile != null) {
                 userProfiles[targetUid] = profile;
              }
           }
        }
      },
      onError: (error) {
        debugPrint('❌ Rooms stream error: $error');
      },
    );
  }
  
  String getOtherUid(List<dynamic> members) {
      return members.firstWhere((id) => id != myUid, orElse: () => '') as String;
  }

  void enterChatRoom(String roomId) {
    messages.clear();
    _messagesStream?.cancel();
    
    scrollController?.dispose();
    scrollController = ScrollController();
    
    debugPrint('💬 Entering chat room: $roomId');
    
    _messagesStream = _repository.getMessages(roomId).listen(
      (snapshot) {
        debugPrint('💬 Stream update: ${snapshot.docs.length} messages');
        messages.value = snapshot.docs;
        
        // Mark incoming messages as read
        _repository.markMessagesAsRead(roomId, myUid);
        
        _scrollToBottom();
      },
      onError: (error) {
        debugPrint('❌ Message stream error: $error');
      },
    );
  }

  void leaveChatRoom() {
    _messagesStream?.cancel();
    messages.clear();
    stopTestBot();
  }

  void _scrollToBottom() {
    if (scrollController == null || !scrollController!.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController?.hasClients ?? false) {
        scrollController!.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void sendMessage(String roomId, String text) {
    if (text.trim().isEmpty) return;
    
    debugPrint('📤 Sending message: "$text" to room $roomId as $myUid');
    _repository.sendMessage(roomId, myUid, text);
  }

  Future<String> createChatRoom(String friendUid) async {
    return await _repository.getOrCreateChatRoom(myUid, friendUid);
  }

  // ─── Test Bot: sends as otherUid (the chat partner) ───
  void runTestBot(String roomId, String otherUid) {
    if (isBotRunning.value) {
      debugPrint('🤖 Bot already running!');
      return;
    }

    isBotRunning.value = true;
    int count = 0;
    const totalMessages = 6;

    final botMessages = [
      '안녕하세요! 테스트 메시지 1입니다 🐶',
      '오늘 산책 다녀왔어요? 테스트 메시지 2입니다 🐾',
      '우리 강아지가 간식을 너무 좋아해요~ 테스트 메시지 3입니다 🦴',
      '다음에 같이 산책할까요? 테스트 메시지 4입니다 🌳',
      '비 오는 날엔 실내 놀이터가 좋아요! 테스트 메시지 5입니다 🏠',
      '좋은 하루 되세요! 테스트 메시지 6입니다 ✨',
    ];

    debugPrint('🤖 Test bot started as "$otherUid"! Will send $totalMessages messages.');

    // Bot sends = other person read my messages first
    _repository.markMessagesFromSenderAsRead(roomId, myUid);
    _repository.sendMessage(roomId, otherUid, botMessages[count]);
    debugPrint('🤖 Bot sent message ${count + 1}/$totalMessages');
    count++;

    _botTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (count >= totalMessages) {
        timer.cancel();
        isBotRunning.value = false;
        debugPrint('🤖 Test bot finished! Sent all $totalMessages messages.');
        return;
      }
      
      // Bot sending = other person read my messages
      _repository.markMessagesFromSenderAsRead(roomId, myUid);
      _repository.sendMessage(roomId, otherUid, botMessages[count]);
      debugPrint('🤖 Bot sent message ${count + 1}/$totalMessages');
      count++;
    });
  }

  void stopTestBot() {
    _botTimer?.cancel();
    isBotRunning.value = false;
    debugPrint('🤖 Test bot stopped.');
  }
}
