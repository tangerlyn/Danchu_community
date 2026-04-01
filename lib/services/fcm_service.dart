import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  // 나중에 서비스 계정 액세스 토큰으로 교체할 자리
  static const _projectId = 'paws-5bd5b';
  // ignore: unused_field
  static const _fcmUrl = 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  // TODO: Apple Developer 가입 후 서비스 계정 키 설정 필요
  // 현재는 토큰 전송 비활성화 상태
  static const bool _isEnabled = false;

  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [FcmService] Initialized');
    } catch (e) {
      debugPrint('⚠️ [FcmService] Init failed: $e');
    }
  }

  static Future<void> saveToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'fcmToken': token});
        debugPrint('✅ [FcmService] Token saved for $uid');
      }
      
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('users').doc(uid)
            .update({'fcmToken': newToken});
        debugPrint('🔄 [FcmService] Token refreshed for $uid');
      });
    } catch (e) {
      debugPrint('⚠️ [FcmService] Token save failed: $e');
    }
  }

  static Future<String?> _getToken(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      debugPrint('⚠️ [FcmService] Failed to fetch token for $uid: $e');
      return null;
    }
  }

  // ignore: unused_element
  static Future<void> _send(String token, String title, String body) async {
    if (!_isEnabled) return; // APNs 설정 전까지 비활성화
    // TODO: 서비스 계정 OAuth2 토큰 발급 후 실제 전송 로직 활성화
    debugPrint('🚀 [FcmService] Sending to $token: $title - $body');
  }

  // 1. 내 게시글에 댓글
  static Future<void> sendCommentNotification({
    required String postAuthorUid,
    required String commenterNickname,
    required String postTitle,
    required String currentUid,
  }) async {
    if (postAuthorUid == currentUid) return;
    final token = await _getToken(postAuthorUid);
    if (token == null) return;
    await _send(token, '새 댓글', '$commenterNickname님이 "$postTitle"에 댓글을 달았습니다.');
  }

  // 2. 내 댓글에 답글
  static Future<void> sendReplyNotification({
    required String commentAuthorUid,
    required String replierNickname,
    required String currentUid,
  }) async {
    if (commentAuthorUid == currentUid) return;
    final token = await _getToken(commentAuthorUid);
    if (token == null) return;
    await _send(token, '새 답글', '$replierNickname님이 내 댓글에 답글을 남겼습니다.');
  }

  // 3. 같은 댓글 스레드에 답글
  static Future<void> sendThreadReplyNotification({
    required List<String> notifyUids,
    required String replierNickname,
    required String currentUid,
  }) async {
    for (final uid in notifyUids) {
      if (uid == currentUid) continue; // Skip self
      final token = await _getToken(uid);
      if (token == null) continue;
      await _send(token, '새 답글', '$replierNickname님이 같은 댓글에 답글을 남겼습니다.');
    }
  }

  // 4. 내 모임에 참여
  static Future<void> sendMeetupJoinNotification({
    required String postAuthorUid,
    required String joinerNickname,
    required String postTitle,
    required String currentUid,
  }) async {
    if (postAuthorUid == currentUid) return;
    final token = await _getToken(postAuthorUid);
    if (token == null) return;
    await _send(token, '모임 참여', '$joinerNickname님이 "$postTitle"에 참여했습니다.');
  }

  // 5. 채팅 알림
  static Future<void> sendChatNotification({
    required List<String> participantUids,
    required String senderNickname,
    required String message,
    required String currentUid,
    required List<String> mutedUids,
  }) async {
    for (final uid in participantUids) {
      if (uid == currentUid) continue;
      if (mutedUids.contains(uid)) continue;
      final token = await _getToken(uid);
      if (token == null) continue;
      await _send(token, senderNickname, message);
    }
  }
}
