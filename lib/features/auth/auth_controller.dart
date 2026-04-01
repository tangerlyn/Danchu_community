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

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen((User? user) async {
      debugPrint("🔄 [AuthController] Auth State Changed: ${user?.uid}");
      if (user == null) {
        // User is logged out or deleted: forcibly kick to login screen
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_profile_completed', false);
        Get.offAll(() => const LoginPage());
      } else {
        // user != null case is NOT handled here. 
        // Login/routing is handled exclusively in loginWithNaver/Kakao methods.
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
      Get.snackbar("로그인 실패", "네이버 로그인 중 오류가 발생했습니다: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          colorText: Colors.white);
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
          Get.offAll(() => MainScreen());
        } else {
          await prefs.setBool('is_profile_completed', false);
          Get.offAll(() => const ProfilePage(isOnboarding: true));
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AuthController] Error during Kakao Login: $e\n$stackTrace");
      Get.snackbar(
        "로그인 실패",
        "카카오 로그인 중 오류가 발생했습니다: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
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

    // ✅ 로컬 산책 기록 삭제 (다른 계정 기록이 보이는 문제 방지)
    try {
      await DatabaseHelper.instance.deleteAllWalks();
      debugPrint("🗑️ Local walk records cleared on logout");
    } catch (e) {
      debugPrint("⚠️ Failed to clear local walks: $e");
    }

    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_profile_completed', false);
    
    // CommunityController 명시적으로 먼저 정리
    if (Get.isRegistered<CommunityController>()) {
      Get.delete<CommunityController>(force: true);
    }

    // Clear all controllers EXCEPT permanent ones (AuthController)
    Get.deleteAll();

    Get.offAll(() => const LoginPage());
  }
}
