import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/app_colors.dart';
import 'history/history_page.dart';
import 'community/community_page.dart';
import 'profile/profile_page.dart';
import 'profile/profile_controller.dart';
import 'community/community_controller.dart';
import '../presentation/home/bindings/home_binding.dart';
import '../presentation/home/views/home_view.dart';
import '../presentation/home/controllers/home_controller.dart';
import '../services/fcm_service.dart';
import '../widgets/overlay_notification.dart';
import 'profile/widgets/live_stats_widget.dart';
import '../widgets/network_banner.dart';
import '../core/network_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Main Screen (Bottom Navigation) ───────────────────────

class MainScreen extends StatefulWidget {
  final int initialIndex;
  MainScreen({Key? key, this.initialIndex = 0})
      : super(key: key ?? ValueKey('main_screen_${DateTime.now().millisecondsSinceEpoch}'));

  /// Accessor for the current MainScreenState (if mounted).
  static _MainScreenState? get currentState {
    final ctx = _MainScreenState._instance;
    return ctx;
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  static _MainScreenState? _instance;

  // GlobalKey to access HistoryPageState for refresh
  final GlobalKey<HistoryPageState> _historyKey = GlobalKey<HistoryPageState>();
  final GlobalKey<LiveStatsWidgetState> _liveStatsKey = GlobalKey<LiveStatsWidgetState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _instance = this;
    _selectedIndex = widget.initialIndex;
    
    // Force delete any trailing disposed instances from previous logins
    Get.delete<HomeController>(force: true);
    
    // NetworkController 재등록 후 즉시 재확인
    if (!Get.isRegistered<NetworkController>()) {
      Get.put(NetworkController(), permanent: true);
    } else {
      // 이미 등록되어 있으면 상태 재확인
      Get.find<NetworkController>().recheck();
    }
    
    // Ensure HomeController is registered when reaching MainScreen
    HomeBinding().dependencies();
    
    // Force instantiation so it's not reused lazily from a phantom cache
    if (!Get.isRegistered<HomeController>()) {
      Get.put(Get.find<HomeController>());
    } else {
      Get.find<HomeController>(); 
    }
    
    // Ensure ProfileController is registered after being purged on logout
    Get.delete<ProfileController>(force: true);
    Get.put(ProfileController());
    // Ensure CommunityController is registered globally to maintain filter state
    // permanent는 유지하되, 로그아웃 시 명시적으로 삭제
    if (Get.isRegistered<CommunityController>()) {
      Get.delete<CommunityController>(force: true);
    }
    Get.put(CommunityController(), permanent: true);

    _pages = [
      const HomeView(),
      HistoryPage(key: _historyKey),
      const CommunityPage(),
      ProfilePage(liveStatsKey: _liveStatsKey),
    ];

    // 앱 버전 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  /// Programmatically switch to a tab (0=Home, 1=History, 2=Profile, 3=Community).
  void switchToTab(int index) {
    _onItemTapped(index);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      // Reset home via GetX controller
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().reset();
      }
    }
    // Auto-refresh history when switching to History tab
    if (index == 1) {
      _historyKey.currentState?.refreshWalks();
    }
    // Auto-refresh profile stats when switching to Profile tab
    if (index == 3) {
      _liveStatsKey.currentState?.refreshStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.deepBrown, width: 0.5)),
            ),
            child: NavigationBar(
              height: 65,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: '홈',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: '기록',
                ),
                NavigationDestination(
                  icon: Obx(() {
                    final controller = Get.find<CommunityController>();
                    final count = controller.totalUnreadCount.value;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      child: const Icon(Icons.forum_outlined),
                    );
                  }),
                  selectedIcon: Obx(() {
                    final controller = Get.find<CommunityController>();
                    final count = controller.totalUnreadCount.value;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      child: const Icon(Icons.forum),
                    );
                  }),
                  label: '이야기',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: '내 정보',
                ),
              ],
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: NetworkBanner(),
        ),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final minVersion = data['minVersion'] as String? ?? '1.0.0';
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isUpdateRequired(currentVersion, minVersion)) {
        _showUpdateDialog(data['updateMessage'] as String?);
      }
    } catch (e) {
      debugPrint('⚠️ Version check failed: $e');
    }
  }

  bool _isUpdateRequired(String current, String min) {
    final cur = current.split('.').map(int.parse).toList();
    final mn = min.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (cur[i] < mn[i]) return true;
      if (cur[i] > mn[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(String? message) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: AppColors.deepBrown),
            SizedBox(width: 8),
            Text('업데이트 안내',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBrown)),
          ],
        ),
        content: Text(
          message ?? '더 나은 서비스를 위해 앱을 최신 버전으로 업데이트해주세요 🐾',
          style: const TextStyle(color: AppColors.mocha, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              // 출시 후 실제 앱스토어 링크로 교체
              // launchUrl(Uri.parse('https://apps.apple.com/app/id앱ID'));
            },
            child: const Text('업데이트',
                style: TextStyle(
                    color: AppColors.deepBrown, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
