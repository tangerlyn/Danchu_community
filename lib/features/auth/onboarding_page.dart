import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../profile/profile_page.dart';
import '../main_screen.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      emoji: '🐾',
      title: '단추에 오신 걸 환영해요!',
      subtitle: '우리 강아지와의 모든 순간을\n함께 기록해요',
      bgColor: Color(0xFFFDF8F4),
    ),
    _OnboardingData(
      emoji: '🗺️',
      title: '산책 기록을 남겨요',
      subtitle: '산책 경로, 거리, 시간을 자동으로 기록하고\n주간·월간 통계로 한눈에 확인해요',
      bgColor: Color(0xFFF5F0EB),
    ),
    _OnboardingData(
      emoji: '🐶',
      title: '우리 강아지 멍카를 만들어요',
      subtitle: '강아지 프로필 카드 멍카를 만들어\n이름, 견종, 나이, 사진을 등록해요',
      bgColor: Color(0xFFFDF8F4),
    ),
    _OnboardingData(
      emoji: '💬',
      title: '강아지 친구들과 이야기 나눠요',
      subtitle: '산책 코스 공유, 실종 신고, 모임 참가까지\n우리 동네 반려견 이웃들과 소통해요',
      bgColor: Color(0xFFF5F0EB),
    ),
    _OnboardingData(
      emoji: '✨',
      title: '지금 바로 시작해볼까요?',
      subtitle: '멍카를 만들고\n단추와 함께 산책을 시작해요 🐾',
      bgColor: Color(0xFFFDF8F4),
      isLast: true,
    ),
  ];

  Future<void> _markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }

  void _goNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() async {
    await _markOnboardingDone();
    // 온보딩 스킵 → 홈탭으로 바로 이동
    Get.offAll(() => MainScreen(initialIndex: 0));
  }

  void _startApp() async {
    await _markOnboardingDone();
    // 멍카 만들러 가기 → 내 정보 탭으로 이동
    Get.offAll(() => MainScreen(initialIndex: 3));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page);
            },
          ),

          // 상단 Skip 버튼
          if (_currentPage < _pages.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: AppColors.taupe,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // 하단 영역 (dot indicator + 버튼)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Dot Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.deepBrown : AppColors.sand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // 버튼
                if (_pages[_currentPage].isLast) ...[
                  // 마지막 페이지
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _startApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBrown,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '멍카 만들러 가기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      '나중에 하기',
                      style: TextStyle(
                        color: AppColors.taupe,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ] else ...[
                  // 일반 페이지
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepBrown,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '다음',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingData page) {
    return Container(
      color: page.bgColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // 이모지 아이콘
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mocha.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    page.emoji,
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // 제목
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBrown,
                  letterSpacing: -0.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              // 부제목
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.mocha,
                  height: 1.7,
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color bgColor;
  final bool isLast;

  const _OnboardingData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    this.isLast = false,
  });
}
