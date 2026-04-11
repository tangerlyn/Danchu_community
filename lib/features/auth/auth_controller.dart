import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:flutter_naver_login/interface/types/naver_account_result.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../config/app_secrets.dart';
import '../../services/fcm_service.dart';
import '../history/database_helper.dart';

import '../main_screen.dart';
import '../profile/profile_page.dart';
import '../profile/profile_controller.dart' as pawprint;
import 'login_page.dart';
import 'onboarding_page.dart';
import '../community/community_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxBool isLoading = false.obs;
  final RxList<String> blockedUsers = <String>[].obs;
  bool _isLoggingOut = false; // logout() 진행 중일 때 authStateChanges 중복 처리 방지

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen((User? user) async {
      debugPrint("🔄 [AuthController] Auth State Changed: ${user?.uid}");
      if (user == null) {
        // 로그아웃 중이면 logout()이 직접 화면 전환을 처리하므로 여기선 스킵
        if (_isLoggingOut) return;
        
        // 로그아웃이 아닌 다른 이유로 user가 null이 된 경우 (세션 만료 등)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_profile_completed', false);
        blockedUsers.clear();
        Get.offAll(() => const LoginPage());
      } else {
        loadBlockedUsers();
      }
    });
  }

  Future<void> loginWithNaver() async {
    debugPrint("🚀 [AuthController] loginWithNaver() Called!");
    debugPrint("🔧 [AuthController] Expected Info - ClientID: ${AppSecrets.naverSearchClientId}");
    isLoading.value = true;
    try {
      // 1. Force clear any lingering Naver session before a fresh login attempt
      debugPrint("🧹 [AuthController] Force clearing previous Naver session...");
      try {
        await FlutterNaverLogin.logOut();
      } catch (e) {
        debugPrint("🧹 [AuthController] logOut ignored (already cleared): $e");
      }

      debugPrint("⏳ [AuthController] Calling FlutterNaverLogin.logIn() (Timeout: 20s)...");
      final NaverLoginResult result = await FlutterNaverLogin.logIn().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception("네이버 로그인 인증 창을 띄우는 데 시간이 너무 오래 걸립니다 (20초 초과).");
        },
      );
      debugPrint("✅ [AuthController] FlutterNaverLogin.logIn() Result: ${result.status}");
      if (result.status == NaverLoginStatus.loggedIn) {
        final NaverAccountResult? account = result.account;
        if (account == null) {
          throw Exception("네이버 계정 정보를 가져올 수 없습니다.");
        }
        
        final String id = account.id ?? '';
        final String email = account.email ?? '';
        final String mobile = account.mobile ?? ''; 
        
        // Use a fallback email if Naver doesn't provide one
        final String safeEmail = email.isNotEmpty ? email : '$id@pawprint.login';

        // 1. Generate secure password from Naver ID + Salt
        final String salt = AppSecrets.authSalt;
        final String password = sha256.convert(utf8.encode(id + salt)).toString().substring(0, 20);

        UserCredential? userCredential;
        bool isNewUser = false;
        try {
          // 2. Try singing in existing session
          userCredential = await _auth.signInWithEmailAndPassword(email: safeEmail, password: password);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
            // 3. If no session exists, create a new one
            userCredential = await _auth.createUserWithEmailAndPassword(email: safeEmail, password: password);
            isNewUser = true;
          } else {
             rethrow;
          }
        }

        // 4. Validate Firestore User Profile
        final user = userCredential.user;
        if (user != null) {
          if (isNewUser) {
            // Save basic user info immediately upon creation
            try {
              debugPrint("⏳ [AuthController] Creating initial Firestore user document...");
              await _firestore.collection('users').doc(user.uid).set({
                'uid': user.uid,
                'email': safeEmail,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
            } catch (e) {
              debugPrint("⚠️ [AuthController] Firestore initial set failed or timed out: $e");
              // Proceed anyway since Auth was successful
            }
          }

          final prefs = await SharedPreferences.getInstance();
          bool hasProfile = false;
          try {
            debugPrint("⏳ [AuthController] Fetching Firestore user document to check profile completion...");
            final doc = await _firestore.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 5));
            final data = doc.data();
            hasProfile = doc.exists && data != null && (data['nickname'] ?? '').toString().isNotEmpty;
          } catch (e) {
            debugPrint("⚠️ [AuthController] Firestore get failed or timed out, assuming incomplete profile: $e");
          }

          isLoading.value = false; // Turn off loader before routing

          // Register for FCM
          await FcmService.saveToken(user.uid);

          if (hasProfile && !isNewUser) {
            // Existing user with completed profile
            await prefs.setBool('is_profile_completed', true);
            await loadBlockedUsers();
            Get.offAll(() => MainScreen());
          } else {
            // New user or incomplete profile: go to Profile setup
            await prefs.setBool('is_profile_completed', false);
            // Save email/phone to prefs so we know what they use
            await prefs.setString('naver_email', safeEmail);
            await prefs.setString('naver_mobile', mobile);

            Get.offAll(() => const ProfilePage(isOnboarding: true));
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AuthController] Error during Naver Login: $e\n$stackTrace");
      Get.snackbar('잠깐!', '로그인에 실패했어요. 다시 시도해주세요 🐾');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Kakao Login ──────────────────────────────────────────────────────
  Future<void> loginWithKakao() async {
    debugPrint("🚀 [AuthController] loginWithKakao() Called!");
    isLoading.value = true;
    try {
      // 1. 카카오톡 설치 여부에 따라 분기
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        debugPrint("📱 [AuthController] KakaoTalk installed → loginWithKakaoTalk()");
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        debugPrint("🌐 [AuthController] KakaoTalk NOT installed → loginWithKakaoAccount()");
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }
      debugPrint("✅ [AuthController] Kakao OAuth Success - accessToken: ${token.accessToken}");

      // 2. 사용자 정보 조회
      final kakao.User kakaoUser = await kakao.UserApi.instance.me();
      final String kakaoId = kakaoUser.id.toString();
      final String? nickname = kakaoUser.kakaoAccount?.profile?.nickname;
      debugPrint("👤 [AuthController] Kakao User Info - id: $kakaoId, nickname: $nickname");

      // 3. Firebase Auth 연동 (카카오 전용 접미사로 네이버와 분리)
      final String safeEmail = 'kakao_$kakaoId@pawprint.login';
      final String salt = "PAWPRINT_SECRET_SALT_2026";
      final String password = sha256.convert(utf8.encode(kakaoId + salt)).toString().substring(0, 20);

      UserCredential? userCredential;
      bool isNewUser = false;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: safeEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' ||
            e.code == 'invalid-credential' ||
            e.code == 'wrong-password') {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: safeEmail,
            password: password,
          );
          isNewUser = true;
        } else {
          rethrow;
        }
      }

      // 4. Firestore 프로필 체크 & 라우팅
      final user = userCredential.user;
      if (user != null) {
        if (isNewUser) {
          try {
            debugPrint("⏳ [AuthController] Creating initial Firestore user document (Kakao)...");
            await _firestore.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'email': safeEmail,
              'provider': 'kakao',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint("⚠️ [AuthController] Firestore initial set failed: $e");
          }
        }

        final prefs = await SharedPreferences.getInstance();
        bool hasProfile = false;
        try {
          debugPrint("⏳ [AuthController] Checking Firestore profile (Kakao)...");
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 5));
          final data = doc.data();
          hasProfile = doc.exists &&
              data != null &&
              (data['nickname'] ?? '').toString().isNotEmpty;
        } catch (e) {
          debugPrint("⚠️ [AuthController] Firestore get failed: $e");
        }

        isLoading.value = false;

        // Register for FCM
        await FcmService.saveToken(user.uid);

        if (hasProfile && !isNewUser) {
          await prefs.setBool('is_profile_completed', true);
          await loadBlockedUsers();
          Get.offAll(() => MainScreen());
        } else {
          await prefs.setBool('is_profile_completed', false);
          Get.offAll(() => const ProfilePage(isOnboarding: true));
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AuthController] Error during Kakao Login: $e\n$stackTrace");
      Get.snackbar('잠깐!', '로그인에 실패했어요. 다시 시도해주세요 🐾');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Email/Password Login (For Reviewers) ─────────────────────────
  Future<void> loginWithEmail(String email, String password) async {
    debugPrint("🚀 [AuthController] loginWithEmail() Called!");
    isLoading.value = true;
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        bool hasProfile = false;
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          final data = doc.data();
          hasProfile = doc.exists && data != null && (data['nickname'] ?? '').toString().isNotEmpty;
        } catch (e) {
          debugPrint("⚠️ [AuthController] Firestore check failed: $e");
        }

        await FcmService.saveToken(user.uid);

        if (hasProfile) {
          await prefs.setBool('is_profile_completed', true);
          await loadBlockedUsers();
          Get.offAll(() => MainScreen());
        } else {
          await prefs.setBool('is_profile_completed', false);
          Get.offAll(() => const ProfilePage(isOnboarding: true));
        }
      }
    } catch (e) {
      debugPrint("❌ [AuthController] Email Login Failed: $e");
      Get.snackbar('잠깐!', '이메일 또는 비밀번호를 다시 확인해주세요 🐾');
    } finally {
      isLoading.value = false;
    }
  }

  // ── Apple Login ──────────────────────────────────────────────────────
  Future<void> loginWithApple() async {
    debugPrint("🚀 [AuthController] loginWithApple() Called!");
    isLoading.value = true;
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

        if (isNewUser) {
          try {
            final fullName = [
              appleCredential.givenName,
              appleCredential.familyName,
            ].where((e) => e != null).join(' ');

            await _firestore.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'email': user.email ?? '',
              'provider': 'apple',
              'displayName': fullName,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
          } catch (e) {
            debugPrint("⚠️ [AuthController] Firestore initial set failed (Apple): $e");
          }
        }

        final prefs = await SharedPreferences.getInstance();
        bool hasProfile = false;
        try {
          final doc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 5));
          final data = doc.data();
          hasProfile = doc.exists &&
              data != null &&
              (data['nickname'] ?? '').toString().isNotEmpty;
        } catch (e) {
          debugPrint("⚠️ [AuthController] Firestore get failed (Apple): $e");
        }

        isLoading.value = false;

        await FcmService.saveToken(user.uid);

        if (hasProfile && !isNewUser) {
          await prefs.setBool('is_profile_completed', true);
          await loadBlockedUsers();
          Get.offAll(() => MainScreen());
        } else {
          await prefs.setBool('is_profile_completed', false);
          Get.offAll(() => const ProfilePage(isOnboarding: true));
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AuthController] Error during Apple Login: $e\n$stackTrace");
      if (e.toString().contains('canceled') || e.toString().contains('AuthorizationErrorCode.canceled')) {
        // 사용자가 직접 취소한 경우 — 스낵바 없이 조용히 처리
        return;
      }
      Get.snackbar('잠깐!', '로그인에 실패했어요. 다시 시도해주세요 🐾');
    } finally {
      isLoading.value = false;
    }
  }


  Future<void> logout() async {
    _isLoggingOut = true;

    // 1. 소셜 로그인 토큰 정리
    try {
      await FlutterNaverLogin.logOut();
    } catch (e) {
      debugPrint("🧹 [AuthController] Naver logOut failed or ignored: $e");
    }
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      debugPrint("🧹 [AuthController] Kakao logOut failed or ignored: $e");
    }

    // 2. 로컬 산책 기록 삭제
    try {
      await DatabaseHelper.instance.deleteAllWalks();
      debugPrint("🗑️ Local walk records cleared on logout");
    } catch (e) {
      debugPrint("⚠️ Failed to clear local walks: $e");
    }

    // 3. 차단 목록 클리어
    blockedUsers.clear();

    // 4. SharedPreferences 초기화
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_profile_completed', false);

    // 5. 화면 전환 전에 컨트롤러 먼저 삭제 (순서 중요!)
    if (Get.isRegistered<CommunityController>()) {
      Get.delete<CommunityController>(force: true);
    }

    // 6. 화면을 LoginPage로 전환
    Get.offAll(() => const LoginPage());

    await Future.delayed(const Duration(milliseconds: 100));

    // 7. Firebase 로그아웃
    await _auth.signOut();

    _isLoggingOut = false;
  }  // ── Block / Unblock ───────────────────────────────────────────────

  /// Firestore에서 현재 사용자의 차단 목록을 불러와서 메모리에 저장
  Future<void> loadBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) {
      blockedUsers.clear();
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null && data['blockedUsers'] is List) {
        blockedUsers.assignAll(List<String>.from(data['blockedUsers']));
        debugPrint("✅ [AuthController] Loaded ${blockedUsers.length} blocked users");
      } else {
        blockedUsers.clear();
      }
    } catch (e) {
      debugPrint("⚠️ [AuthController] Failed to load blocked users: $e");
      blockedUsers.clear();
    }
  }

  /// 사용자 차단
  Future<void> blockUser(String targetUid, {String? targetNickname}) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar('알림', '로그인이 필요합니다.');
      return;
    }
    if (targetUid == user.uid) {
      Get.snackbar('알림', '본인을 차단할 수 없습니다.');
      return;
    }
    if (blockedUsers.contains(targetUid)) {
      Get.snackbar('알림', '이미 차단된 사용자입니다.');
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
      }, SetOptions(merge: true));
      blockedUsers.add(targetUid);

      // 개발자에게 차단 알림 기록 (Apple 4.8 가이드라인 대응)
      await _firestore.collection('reports').add({
        'type': 'block',
        'reporterUid': user.uid,
        'targetUid': targetUid,
        'targetNickname': targetNickname ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        '차단 완료',
        targetNickname != null
            ? '$targetNickname님을 차단했습니다.\n해당 사용자의 게시글과 댓글이 보이지 않습니다.'
            : '사용자를 차단했습니다.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint("❌ [AuthController] Failed to block user: $e");
      Get.snackbar('오류', '차단에 실패했습니다. 다시 시도해주세요.');
    }
  }

  /// 차단 해제
  Future<void> unblockUser(String targetUid, {String? targetNickname}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'blockedUsers': FieldValue.arrayRemove([targetUid]),
      }, SetOptions(merge: true));
      blockedUsers.remove(targetUid);
      Get.snackbar(
        '차단 해제',
        targetNickname != null
            ? '$targetNickname님의 차단을 해제했습니다.'
            : '차단을 해제했습니다.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint("❌ [AuthController] Failed to unblock user: $e");
      Get.snackbar('오류', '차단 해제에 실패했습니다.');
    }
  }

  /// 특정 사용자가 차단되어 있는지 확인
  bool isUserBlocked(String uid) => blockedUsers.contains(uid);
}
