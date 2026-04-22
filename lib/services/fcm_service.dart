import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  static final _functions = FirebaseFunctions.instance;

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

  static Future<void> _call(String functionName, Map<String, dynamic> params) async {
    try {
      await _functions.httpsCallable(functionName).call(params);
      debugPrint('🚀 [FcmService] Called $functionName with $params');
    } catch (e) {
      debugPrint('⚠️ [FcmService] $functionName failed: $e');
    }
  }

  // 1. 내 게시글에 댓글
  static Future<void> sendCommentNotification({
    required String postAuthorUid,
    required String commenterNickname,
    required String postTitle,
    required String postId,
    required String currentUid,
  }) async {
    if (postAuthorUid == currentUid) return;
    await _call('sendCommentNotification', {
      'postAuthorUid': postAuthorUid,
      'commenterNickname': commenterNickname,
      'postTitle': postTitle,
      'postId': postId,
    });
  }

  // 2. 내 댓글에 답글
  static Future<void> sendReplyNotification({
    required String commentAuthorUid,
    required String replierNickname,
    required String postId,
    required String currentUid,
  }) async {
    if (commentAuthorUid == currentUid) return;
    await _call('sendReplyNotification', {
      'commentAuthorUid': commentAuthorUid,
      'replierNickname': replierNickname,
      'postId': postId,
    });
  }

  // 3. 같은 댓글 스레드에 답글
  static Future<void> sendThreadReplyNotification({
    required List<String> notifyUids,
    required String replierNickname,
    required String postId,
    required String currentUid,
  }) async {
    final uids = notifyUids.where((uid) => uid != currentUid).toList();
    if (uids.isEmpty) return;
    await _call('sendThreadReplyNotification', {
      'notifyUids': uids,
      'replierNickname': replierNickname,
      'postId': postId,
    });
  }

  // 4. 내 모임에 참여
  static Future<void> sendMeetupJoinNotification({
    required String postAuthorUid,
    required String joinerNickname,
    required String postTitle,
    required String postId,
    required String currentUid,
  }) async {
    if (postAuthorUid == currentUid) return;
    await _call('sendMeetupJoinNotification', {
      'postAuthorUid': postAuthorUid,
      'joinerNickname': joinerNickname,
      'postTitle': postTitle,
      'postId': postId,
    });
  }

  // 5. 채팅 알림
  static Future<void> sendChatNotification({
    required List<String> participantUids,
    required String senderNickname,
    required String message,
    required String postId,
    required String currentUid,
    required List<String> mutedUids,
  }) async {
    final uids = participantUids.where((uid) => uid != currentUid).toList();
    if (uids.isEmpty) return;
    await _call('sendChatNotification', {
      'participantUids': uids,
      'senderNickname': senderNickname,
      'message': message,
      'postId': postId,
      'mutedUids': mutedUids,
    });
  }

  // 6. 참가 신청 결과 (승인/거절)
  static Future<void> sendJoinResultNotification({
    required String targetUid,
    required String postId,
    required bool isAccepted,
  }) async {
    await _call('sendJoinResultNotification', {
      'targetUid': targetUid,
      'postId': postId,
      'isAccepted': isAccepted,
    });
  }

  // 7. 친구 요청 알림
  static Future<void> sendFriendRequestNotification({
    required String toUid,
    required String fromNickname,
  }) async {
    await _call('sendFriendRequestNotification', {
      'toUid': toUid,
      'fromNickname': fromNickname,
    });
  }

  // 8. 친구 수락 알림
  static Future<void> sendFriendAcceptedNotification({
    required String toUid,
    required String fromNickname,
  }) async {
    await _call('sendFriendAcceptedNotification', {
      'toUid': toUid,
      'fromNickname': fromNickname,
    });
  }

  // 9. 1대1 채팅 알림
  static Future<void> sendDirectChatNotification({
    required String toUid,
    required String senderNickname,
    required String message,
    required String currentUid,
  }) async {
    if (toUid == currentUid) return;
    await _call('sendDirectChatNotification', {
      'toUid': toUid,
      'senderNickname': senderNickname,
      'message': message,
    });
  }
}
