import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_colors.dart';

/// 앱 전반의 에러 처리 및 피드백 메시지를 통일합니다.
class AppErrorHandler {
  AppErrorHandler._();

  static void showError(String message) {
    Get.snackbar(
      '오류',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent.withOpacity(0.85),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  static void showSuccess(String message) {
    Get.snackbar(
      '✅ 완료',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.deepBrown,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }

  static void showInfo(String message) {
    Get.snackbar(
      '알림',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.mocha.withOpacity(0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
    );
  }
}
