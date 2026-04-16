import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'config/app_secrets.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/profile/profile_page.dart';
import 'presentation/home/bindings/home_binding.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'features/main_screen.dart';
import 'core/app_colors.dart';
import 'core/network_controller.dart';
import 'features/auth/onboarding_page.dart';
import 'features/community/post_detail_page.dart';
import 'features/community/meetup_chat_page.dart';
import 'data/repositories/community_repository_impl.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await FlutterNaverMap().init(
    clientId: '4erd0jhvuv',
    onAuthFailed: (ex) => print("********* 네이버맵 인증오류 : $ex *********"),
  );
  debugPrint('🗺️ Naver Map SDK initialized with: 4erd0jhvuv');

  // Kakao SDK 초기화
  KakaoSdk.init(nativeAppKey: AppSecrets.kakaoNativeAppKey);

  await Firebase.initializeApp();
  debugPrint('🔥 Firebase Initialized Success!');

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FcmService.init();
  await LocalNotificationService.init();
  debugPrint('🔔 FCM & Local Notif Initialized!');

  // 알림 클릭 핸들러
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _handleNotificationClick(message);
  });

  // 앱이 완전히 꺼진 상태에서 알림 클릭
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      _handleNotificationClick(message);
    }
  });

  await initializeDateFormatting('ko');

  final prefs = await SharedPreferences.getInstance();
  final isProfileCompleted = prefs.getBool('is_profile_completed') ?? false;
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  final isLoggedIn = FirebaseAuth.instance.currentUser != null;
  debugPrint('🚀 Onboarding Check: isProfileCompleted=$isProfileCompleted, isLoggedIn=$isLoggedIn');

  Get.put(NetworkController(), permanent: true);

  // 스플래시 최소 표시 시간 보장 (iOS에서 너무 빨리 사라지는 문제 방지)
  await Future.delayed(const Duration(milliseconds: 1500));
  FlutterNativeSplash.remove();

  runApp(PawprintApp(
    isProfileCompleted: isProfileCompleted,
    isLoggedIn: isLoggedIn,
    hasSeenOnboarding: hasSeenOnboarding,
  ));
}

class PawprintApp extends StatelessWidget {
  final bool isProfileCompleted;
  final bool isLoggedIn;
  final bool hasSeenOnboarding;

  const PawprintApp({
    super.key,
    required this.isProfileCompleted,
    required this.isLoggedIn,
    required this.hasSeenOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    HomeBinding().dependencies();
    Get.put(AuthController(), permanent: true); // Permanent — survives logout deleteAll

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: '단추',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: const ColorScheme.light(
          primary: AppColors.deepBrown,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.sand,
          onPrimaryContainer: AppColors.deepBrown,
          secondary: AppColors.latte,
          onSecondary: AppColors.white,
          secondaryContainer: AppColors.sand,
          onSecondaryContainer: AppColors.mocha,
          surface: AppColors.white,
          onSurface: AppColors.deepBrown,
          surfaceContainerHighest: AppColors.sand,
          outline: AppColors.taupe,
          outlineVariant: AppColors.sand,
        ),
        dividerColor: AppColors.sand,
        dividerTheme: const DividerThemeData(color: AppColors.sand, thickness: 1),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.deepBrown,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.deepBrown,
          foregroundColor: AppColors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepBrown,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.deepBrown,
            side: const BorderSide(color: AppColors.taupe),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.deepBrown),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.white,
          indicatorColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.deepBrown);
            }
            return const IconThemeData(color: AppColors.taupe);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: AppColors.deepBrown, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: AppColors.taupe, fontSize: 12);
          }),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F0EB),
          hintStyle: const TextStyle(color: AppColors.taupe),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0D8D0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.deepBrown, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        iconTheme: const IconThemeData(color: AppColors.latte),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.mocha, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: AppColors.mocha, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: AppColors.latte),
          bodyMedium: TextStyle(color: AppColors.latte),
          bodySmall: TextStyle(color: AppColors.taupe),
          labelLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(color: AppColors.taupe),
        ),
      ),
      home: isLoggedIn
          ? (isProfileCompleted
               ? MainScreen()
               : const ProfilePage(isOnboarding: true))
          : const LoginPage(),
    );
  }
}

void _handleNotificationClick(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];
  final postId = data['postId'];

  if (postId == null) return;

  Future.delayed(const Duration(milliseconds: 500), () async {
    if (type == 'chat' || type == 'meetup') {
      // 채팅방으로 이동
      final repo = CommunityRepositoryImpl();
      final post = await repo.getPostById(postId);
      if (post != null) {
        Get.to(() => MeetupChatPage(
          postId: postId,
          postTitle: post.title,
        ));
      }
    } else if (type == 'comment' || type == 'reply') {
      // 게시글로 이동
      final repo = CommunityRepositoryImpl();
      final post = await repo.getPostById(postId);
      if (post != null) {
        Get.to(() => PostDetailPage(post: post));
      }
    }
  });
}

