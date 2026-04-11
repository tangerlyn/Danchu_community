import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
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
      imagePath: 'assets/onboarding/slide1.png',
      title: '단추에 오신 걸\n환영해요!',
      subtitle: '우리 강아지와의 모든 순간을\n함께 기록해요',
      bgColor: Color(0xFFFDF8F4),
    ),
    _OnboardingData(
      imagePath: 'assets/onboarding/slide2.png',
      title: '산책 기록을\n남겨요',
      subtitle: '산책 경로, 거리, 시간을 자동으로 기록하고\n주간·월간 통계로 한눈에 확인해요',
      bgColor: Color(0xFFF5F0EB),
    ),
    _OnboardingData(
      imagePath: 'assets/onboarding/slide3.png',
      title: '우리 강아지\n단추 카드를 만들어요',
      subtitle: '강아지 프로필 카드 단카를 만들어\n이름, 견종, 나이, 사진을 등록해요',
      bgColor: Color(0xFFFDF8F4),
    ),
    _OnboardingData(
      imagePath: 'assets/onboarding/slide4.png',
      title: '다른 친구들과\n이야기 나눠요',
      subtitle: '산책 코스 공유, 실종 제보, 모임 참가까지\n우리 동네 반려견 이웃들과 소통해요',
      bgColor: Color(0xFFF5F0EB),
    ),
    _OnboardingData(
      imagePath: 'assets/onboarding/slide5.png',
      title: '지금 바로\n시작해볼까요?',
      subtitle: '단카를 만들고\n단추와 함께 산책을 시작해요',
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
    Get.offAll(() => MainScreen(initialIndex: 0));
  }

  void _startApp() async {
    await _markOnboardingDone();
    Get.offAll(() => MainScreen(initialIndex: 3));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),

          // 건너뛰기 버튼
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

          // 하단 dot + 버튼
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 24),
                if (_pages[_currentPage].isLast) ...[
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
                        '단카 만들러 가기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _skip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sand,
                        foregroundColor: AppColors.deepBrown,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        '나중에 하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ] else
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingData page) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    // 마지막 페이지는 이미지 없이 가운데 정렬
    if (page.isLast) {
      return Container(
        color: page.bgColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown,
                    letterSpacing: -0.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.mocha,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: page.bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: topPadding + screenHeight * 0.08),
          // 제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppColors.deepBrown,
                letterSpacing: -0.5,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 소제목
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.mocha,
                height: 1.7,
              ),
            ),
          ),
          const Spacer(),
          // 핸드폰 프레임 이미지 (하단에 딱 붙게)
          if (page.imagePath != null)
            Builder(
              builder: (context) {
                // 1. 핸드폰 높이는 화면 높이의 62%를 목표로
                double phoneHeight = screenHeight * 0.62;
                // 2. 핸드폰 너비는 실제 폰 비율(약 9:19.5)로 계산
                double phoneWidth = phoneHeight * (9 / 19.5);

                // 3. 너비가 화면 너비의 85%를 넘으면 너비 기준으로 재계산
                final maxWidth = screenWidth * 0.85;
                if (phoneWidth > maxWidth) {
                  phoneWidth = maxWidth;
                  phoneHeight = phoneWidth * (19.5 / 9);
                }

                return Container(
                  width: phoneWidth,
                  height: phoneHeight,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 8),
                      left: BorderSide(color: Colors.black, width: 8),
                      right: BorderSide(color: Colors.black, width: 8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(33),
                      topRight: Radius.circular(33),
                    ),
                    child: Image.asset(
                      page.imagePath!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String? imagePath;
  final String title;
  final String subtitle;
  final Color bgColor;
  final bool isLast;

  const _OnboardingData({
    this.imagePath,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    this.isLast = false,
  });
}
