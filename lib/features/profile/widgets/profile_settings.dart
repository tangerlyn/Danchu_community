import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import '../../../core/app_colors.dart';
import '../profile_controller.dart';
import '../../history/database_helper.dart';
import '../notification_settings_page.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_controller.dart';
import '../../auth/login_page.dart';

/// Shows settings bottom sheet with onboarding reset and account deletion.
void showSettingsMenu(BuildContext context, ProfileController controller) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.deepBrown),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.deepBrown),
                title: const Text('프로필 수정', style: TextStyle(color: AppColors.deepBrown)),
                onTap: () {
                  Navigator.pop(ctx);
                  controller.toggleEdit();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: AppColors.deepBrown),
                title: const Text('알림 설정', style: TextStyle(color: AppColors.deepBrown)),
                onTap: () {
                  Navigator.pop(ctx);
                  Get.to(() => const NotificationSettingsPage());
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.deepBrown),
                title: const Text('로그아웃', style: TextStyle(color: AppColors.deepBrown)),
                onTap: () async {
                  Navigator.pop(ctx);
                  Get.put(AuthController());
                  await Get.find<AuthController>().logout();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_off, color: AppColors.deepBrown),
                title: Text('회원 탈퇴하기', style: TextStyle(color: AppColors.deepBrown)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountDialog(context, controller);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    },
  );
}

void _showDeleteAccountDialog(BuildContext context, ProfileController controller) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.deepBrown, size: 28),
            const SizedBox(width: 8),
            const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n모든 데이터가 삭제됩니다.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: AppColors.taupe)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performAccountDeletion(controller);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepBrown,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('탈퇴하기'),
          ),
        ],
      );
    },
  );
}

Future<void> _performAccountDeletion(ProfileController controller) async {
  // Navigate away from MainScreen to unmount all controllers and cancel active Firestore streams
  Get.offAll(() => Scaffold(
    backgroundColor: AppColors.white,
    body: Center(child: CircularProgressIndicator(color: AppColors.deepBrown)),
  ));
  
  try {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) {
      throw Exception('현재 로그인된 사용자 정보가 없습니다.');
    }

    final uid = user.uid;

    // ✅ Storage 이미지 먼저 삭제 (서브컬렉션 삭제 전에!)
    debugPrint('🗑️ [Account Deletion] Deleting profile & dog images from Storage...');
    try {
      final storage = FirebaseStorage.instance;

      // 프로필 사진 삭제
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final profileImageUrl = userDoc.data()?['profileImageUrl'] as String?;
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          try {
            await storage.refFromURL(profileImageUrl).delete();
            debugPrint('✅ Profile image deleted');
          } catch (e) {
            debugPrint('⚠️ Profile image delete failed (ignored): $e');
          }
        }
      }

      // 강아지 사진 삭제
      final dogsSnapshot = await firestore
          .collection('users').doc(uid).collection('dogs').get();
      for (final dogDoc in dogsSnapshot.docs) {
        final dogImageUrl = dogDoc.data()['profileImageUrl'] as String?;
        if (dogImageUrl != null && dogImageUrl.isNotEmpty) {
          try {
            await storage.refFromURL(dogImageUrl).delete();
            debugPrint('✅ Dog image deleted: ${dogDoc.id}');
          } catch (e) {
            debugPrint('⚠️ Dog image delete failed (ignored): $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Storage image deletion failed (ignored): $e');
    }
    debugPrint('✅ [Account Deletion] Storage images deleted');

    // 1. users 서브컬렉션 삭제
    debugPrint('🗑️ [Account Deletion] Deleting users subcollections...');
    for (final sub in ['dogs', 'friends', 'walks', 'schedules', 
        'notification_settings', 'bookmarked_places']) {
      final snapshot = await firestore.collection('users').doc(uid).collection(sub).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }
    debugPrint('✅ [Account Deletion] Users subcollections deleted');

    // 2. 내가 쓴 게시글 익명화 (authorUid 제거, authorNickname → '탈퇴한 사용자')
    debugPrint('📝 [Account Deletion] Anonymizing community posts authored by user...');
    final posts = await firestore
        .collection('community_posts')
        .where('authorUid', isEqualTo: uid)
        .get();
    for (final doc in posts.docs) {
      await doc.reference.update({
        'authorUid': '',
        'authorNickname': '탈퇴한 사용자',
      });
    }
    debugPrint('✅ [Account Deletion] Community posts anonymized');

    // 3. 내가 쓴 댓글 익명화
    debugPrint('📝 [Account Deletion] Anonymizing user comments on other posts...');
    final comments = await firestore
        .collectionGroup('comments')
        .where('authorUid', isEqualTo: uid)
        .get();
    for (final doc in comments.docs) {
      await doc.reference.update({
        'authorUid': '',
        'authorNickname': '탈퇴한 사용자',
      });
    }
    debugPrint('✅ [Account Deletion] User comments anonymized');

    // 4. 모임 참가 취소 (내가 참가한 모임에서 나가기)
    debugPrint('🚪 [Account Deletion] Leaving all joined meetings...');
    final joinedChats = await firestore
        .collection('users').doc(uid).collection('joined_chats').get();
    for (final doc in joinedChats.docs) {
      final postId = doc.id;
      // 1. 참여자 목록에서 내 문서 삭제
      try {
        debugPrint('🔍 참여 여부 확인: community_posts/$postId/participants/$uid');
        final participantDoc = await firestore
            .collection('community_posts')
            .doc(postId)
            .collection('participants')
            .doc(uid)
            .get();

        if (!participantDoc.exists) {
          debugPrint('⚠️ participants/$uid 문서 없음 - 스킵');
          continue;
        }

        await participantDoc.reference.delete();
        // 2. 참여자 수 감소 후 0명이면 게시글 및 서브컬렉션 전체 삭제
        await firestore
            .collection('community_posts')
            .doc(postId)
            .update({'currentParticipantCount': FieldValue.increment(-1)});

        // 감소 후 실제 participants 수 확인
        final remainingParticipants = await firestore
            .collection('community_posts')
            .doc(postId)
            .collection('participants')
            .get();

        if (remainingParticipants.docs.isEmpty) {
          // 권한 에러를 일으키는 서브컬렉션 개별 삭제 루프 제거
          // 메인 게시글 문서만 삭제하여 리스트에서 보이지 않게 처리
          await firestore.collection('community_posts').doc(postId).delete();
          debugPrint('🗑️ 마지막 참가자 탈퇴 → 모임 게시글 삭제 완료: $postId');
        }
      } catch (e) {
        debugPrint('⚠️ [Account Deletion] Failed to leave meeting $postId (maybe post deleted): $e');
      }
      
      // 3. 내 joined_chats 문서 삭제
      await doc.reference.delete();
    }
    debugPrint('✅ [Account Deletion] Joined meetings cleanup completed');


    // Delete local walks
    debugPrint('🗑️ [Account Deletion] Deleting local walks...');
    await DatabaseHelper.instance.deleteAllWalks();
    debugPrint('✅ [Account Deletion] Local walks deleted');

    // Delete user document
    debugPrint('🗑️ [Account Deletion] Deleting users/$uid document...');
    await firestore.collection('users').doc(uid).delete();
    debugPrint('✅ [Account Deletion] Firestore users/$uid document deleted');

    // Clear local cache
    // authStateChanges 리스너가 온보딩으로 리다이렉트 못하도록 먼저 플래그 초기화
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_profile_completed', false);
    await prefs.remove('naver_email');
    await prefs.remove('naver_mobile');
    await prefs.clear();

    // Firebase Auth 삭제 시도 (재인증 에러 나도 무시하고 진행)
    debugPrint('🗑️ [Account Deletion] Deleting FirebaseAuth user...');
    try {
      await user.delete();
      debugPrint('✅ [Account Deletion] Auth user deleted');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ [Account Deletion] Auth delete failed (ignored): ${e.code}');
      // 데이터는 이미 지워졌으므로 그냥 진행
    }

    // Clear OAuth tokens and unlink
    debugPrint('🗑️ [Account Deletion] Clearing OAuth tokens (Naver/Kakao)...');
    try {
      await FlutterNaverLogin.logOutAndDeleteToken();
    } catch (e) {
      debugPrint('⚠️ [Account Deletion] Naver token cleanup ignored: $e');
    }
    
    try {
      await kakao.UserApi.instance.unlink();
    } catch (e) {
      debugPrint('⚠️ [Account Deletion] Kakao token cleanup ignored: $e');
    }

    // Explicitly delete ALL controllers to prevent disposed caching issues (force: true kills permanent ones too)
    Get.deleteAll(force: true);

    await FirebaseAuth.instance.signOut();
    Get.put(AuthController());
    Get.offAll(() => const LoginPage());

    Get.snackbar('탈퇴 완료', '모든 데이터가 삭제되었습니다.', snackPosition: SnackPosition.TOP);
  } catch (e) {
    debugPrint('❌ Account deletion error: $e');
    Get.snackbar('잠깐!', '탈퇴 처리 중 문제가 발생했어요. 고객센터로 문의해주세요 🐾');
  }
}
