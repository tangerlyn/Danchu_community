import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import 'auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthController is permanent — safely retrieve or register it
    final authController = Get.isRegistered<AuthController>() 
        ? Get.find<AuthController>() 
        : Get.put(AuthController());

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo or App Name
              const Icon(
                Icons.pets,
                size: 80,
                color: AppColors.deepBrown,
              ),
              const SizedBox(height: 24),
              const Text(
                '단추모임',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '반려견과의 소중한 기록을\n시작해볼까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mocha,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              
              // Naver Login Button
              Obx(() => authController.isLoading.value
                  ? const Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Naver ─────────────────────────────
                        ElevatedButton(
                          onPressed: () => authController.loginWithNaver(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF03C75A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'N',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '네이버로 시작하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Kakao ─────────────────────────────
                        ElevatedButton(
                          onPressed: () => authController.loginWithKakao(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE500),
                            foregroundColor: const Color(0xFF191919),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://developers.kakao.com/assets/img/about/logos/kakaologin/kr/kakao_login_medium_narrow.png',
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.chat_bubble,
                                  size: 20,
                                  color: Color(0xFF191919),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '카카오로 시작하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
