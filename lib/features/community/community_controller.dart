import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/community_post.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../data/repositories/meetup_chat_repository.dart';
import 'community_constants.dart';
import '../auth/auth_controller.dart';

class CommunityController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  final MeetupChatRepository _chatRepository = MeetupChatRepository();
  
  // Selected Categories
  var selectedMainCategoryIndex = 0.obs;
  var selectedSubCategory = '전체'.obs;

  // Near Me Filter (Phase 3)
  var isNearMeActive = false.obs;
  Position? _currentPosition;

  // My Meetup Filter
  var isMyMeetupActive = false.obs;

  // Set of post IDs where current user is a participant (for badge display)
  var myMeetupPostIds = <String>{}.obs;

  // Total unread chat message count (for tab badge)
  var totalUnreadCount = 0.obs;
  var unreadCountsMap = <String, int>{}.obs;
  final Map<String, StreamSubscription<int>> _unreadSubscriptions = {};

  // FAB Popup state
  var isWriteMenuOpen = false.obs;

  // Scroll to Top UI
  final scrollController = ScrollController();
  var showScrollToTop = false.obs;

  void toggleWriteMenu() {
    isWriteMenuOpen.value = !isWriteMenuOpen.value;
  }

  // Stream of Posts
  StreamSubscription? _postsSubscription;
  final Map<String, StreamSubscription> _hotPostsSubscriptions = {};
  Rx<List<CommunityPost>> posts = Rx<List<CommunityPost>>([]);
  var isPostsLoading = true.obs;

  // Hot posts for each category ('산책', '제보', '자유')
  final hotPostsMap = <String, Rx<List<CommunityPost>>>{
    '산책': Rx<List<CommunityPost>>([]),
    '제보': Rx<List<CommunityPost>>([]),
    '자유': Rx<List<CommunityPost>>([]),
  };

  // ─── Search History ─────────────────────────────────────
  static const _historyKey = 'community_search_history';
  final searchHistory = <String>[].obs;

  // ─── Timers ──────────────────────────
  Timer? _initialTimer;
  Timer? _periodicTimer;

  @override
  void onInit() {
    super.onInit();
    _bindPostsStream();
    _bindAllHotPosts();
    _scheduleRefresh();
    _loadSearchHistory();
    _loadMyMeetupPostIds();

    scrollController.addListener(() {
      if (scrollController.offset >= 300 && !showScrollToTop.value) {
        showScrollToTop.value = true;
      } else if (scrollController.offset < 300 && showScrollToTop.value) {
        showScrollToTop.value = false;
      }
    });

    // 차단 목록이 변경되면 현재 피드를 다시 필터링
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      ever(auth.blockedUsers, (_) {
        final currentPosts = posts.value;
        final refiltered = _filterBlockedUsers(currentPosts);
        if (refiltered.length != currentPosts.length) {
          // 차단된 사용자의 글이 있어서 즉시 숨김
          posts.value = refiltered;
        } else {
          // 차단 해제의 경우 스트림 재바인딩으로 데이터 새로 받아오기
          _bindPostsStream();
        }
      });
    }
  }

  @override
  void onClose() {
    _postsSubscription?.cancel();
    _postsSubscription = null;
    _initialTimer?.cancel();
    _periodicTimer?.cancel();
    for (final sub in _unreadSubscriptions.values) {
      sub.cancel();
    }
    _unreadSubscriptions.clear();
    unreadCountsMap.clear();
    totalUnreadCount.value = 0;
    for (final sub in _hotPostsSubscriptions.values) {
      sub.cancel();
    }
    _hotPostsSubscriptions.clear();
    posts.value = [];
    if (scrollController.hasClients) {
      scrollController.dispose();
    }
    super.onClose();
  }

  void scrollToTop() {
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // --- Near Me Filter Methods (Phase 3) ---
  Future<void> toggleNearMeFilter() async {
    if (isNearMeActive.value) {
      isNearMeActive.value = false;
      _currentPosition = null;
      _bindPostsStream();
    } else {
      try {
        // 권한 확인 및 요청
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            Get.snackbar('알림', '위치 권한이 필요합니다.');
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          Get.snackbar('알림', '설정에서 위치 권한을 허용해주세요.');
          return;
        }

        // 1. 먼저 마지막으로 알려진 위치를 즉시 가져오기 시도
        Position? pos = await Geolocator.getLastKnownPosition();

        // 2. 마지막 위치가 없으면 현재 위치 새로 가져오기
        pos ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );

        // 3. 그래도 위치를 못 가져오면 에러 처리
        if (pos == null) {
          Get.snackbar('알림', '현재 위치를 가져올 수 없습니다. 잠시 후 다시 시도해주세요.');
          return;
        }

        _currentPosition = pos;
        isNearMeActive.value = true;
        _bindPostsStream();

        Get.snackbar(
          '내 위치 기준',
          '반경 5km 이내의 게시글만 표시됩니다.',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF3E2723).withOpacity(0.9), // Using deep brown hex directly to avoid app_colors dependency if not imported correctly
          colorText: Colors.white,
          borderRadius: 12,
          margin: const EdgeInsets.all(16),
          icon: const Icon(Icons.location_on, color: Colors.white, size: 20),
        );
      } catch (e) {
        debugPrint('⚠️ Error toggling near me filter: $e');
        Get.snackbar('잠깐!', '위치 정보를 가져오는 중 문제가 발생했어요 🐾');
      }
    }
  }

  void toggleMyMeetupFilter() {
    if (isMyMeetupActive.value) {
      isMyMeetupActive.value = false;
      posts.value = []; // Clear first to prevent flash
      _bindPostsStream();
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('알림', '로그인이 필요합니다.');
        return;
      }
      posts.value = []; // Clear first to prevent flash
      isMyMeetupActive.value = true;
      _bindPostsStream();
    }
  }

  Future<void> _loadMyMeetupPostIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ids = await _repository.getMyParticipatingPostIds(uid);
      myMeetupPostIds.assignAll(ids);
      _listenToUnreadCounts();
    } catch (e) {
      debugPrint('⚠️ [CommunityController] Failed to load my meetup post IDs: $e');
    }
  }

  /// Refresh the badge data (call after joining/leaving a meetup)
  void refreshMyMeetupPostIds() => _loadMyMeetupPostIds();

  /// Listen to real-time streams for all participated chat rooms
  void _listenToUnreadCounts() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currentIds = myMeetupPostIds.toList();

    // Cancel subscriptions for chats we left or were removed
    final leftChats = _unreadSubscriptions.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in leftChats) {
      _unreadSubscriptions[id]?.cancel();
      _unreadSubscriptions.remove(id);
      unreadCountsMap.remove(id);
    }

    // Subscribe to new joined chats
    for (final id in currentIds) {
      if (!_unreadSubscriptions.containsKey(id)) {
        _unreadSubscriptions[id] = _chatRepository.getUnreadCountStream(id, uid).listen((count) {
          unreadCountsMap[id] = count;
          _calculateTotalUnread();
        });
      }
    }
    _calculateTotalUnread();
  }

  void _calculateTotalUnread() {
    totalUnreadCount.value = unreadCountsMap.values.fold(0, (sum, count) => sum + count);
  }

  /// Cancel unread subscription immediately (e.g. when leaving a chat room)
  void cancelUnreadSubscription(String postId) {
    _unreadSubscriptions[postId]?.cancel();
    _unreadSubscriptions.remove(postId);
    unreadCountsMap.remove(postId);
    _calculateTotalUnread();
  }

  // ─── Search History Methods ─────────────────────────────

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    searchHistory.value = prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addSearchHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    searchHistory.remove(trimmed);
    searchHistory.insert(0, trimmed);
    if (searchHistory.length > 20) searchHistory.removeLast();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);
  }

  Future<void> removeSearchHistory(String query) async {
    searchHistory.remove(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, searchHistory);
  }

  Future<void> clearAllSearchHistory() async {
    searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// Search posts by query (title or content match, case-insensitive)
  List<CommunityPost> searchPosts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return posts.value.where((p) {
      return p.title.toLowerCase().contains(q) ||
             p.content.toLowerCase().contains(q);
    }).toList();
  }

  void _bindPostsStream() {
    final mainCategory = CommunityConstants.mainCategories[selectedMainCategoryIndex.value];
    isPostsLoading.value = true;
    
    Stream<List<CommunityPost>> stream;

    // 1. "My Meetup" + "Near Me" combination for '모임' tab
    if (mainCategory == '모임' && isMyMeetupActive.value) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        isPostsLoading.value = false;
        return;
      }

      stream = _repository.getMyMeetupPostsStream(uid);

      if (isNearMeActive.value && _currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        const radius = 5.0; // 5km radius
        stream = stream.map((postList) {
          return postList.where((post) {
            if (post.lat == null || post.lng == null) return false;
            final dist = Geolocator.distanceBetween(lat, lng, post.lat!, post.lng!) / 1000.0;
            return dist <= radius;
          }).toList();
        });
      }
    } else {
      // 2. Default cases (Global vs Near Me) without "My Meetup"
      if (isNearMeActive.value && _currentPosition != null) {
        stream = _repository.getNearbyPostsStream(
          lat: _currentPosition!.latitude,
          lng: _currentPosition!.longitude,
          mainCategory: mainCategory,
          subCategory: selectedSubCategory.value == '전체' ? null : selectedSubCategory.value,
        );
      } else {
        stream = _repository.getPostsStream(
          mainCategory: mainCategory,
          subCategory: selectedSubCategory.value == '전체' ? null : selectedSubCategory.value,
        );
      }
    }

    // 기존 구독 취소
    _postsSubscription?.cancel();
    
    // 새 스트림 구독
    _postsSubscription = stream.listen((data) {
      // 차단된 사용자의 게시글 필터링
      final filtered = _filterBlockedUsers(data);
      posts.value = filtered;
      isPostsLoading.value = false;
    });
  }

  Future<void> refreshPosts() async {
    if (isNearMeActive.value) {
      try {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
        if (pos != null) _currentPosition = pos;
      } catch (_) {}
    }
    _bindPostsStream();
    // RefreshIndicator가 자연스럽게 사라지도록 stream이 첫 데이터를 받을 시간을 줌
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _bindAllHotPosts() {
    final categories = ['산책', '제보', '자유'];
    for (final cat in categories) {
      _hotPostsSubscriptions[cat]?.cancel();
      _hotPostsSubscriptions[cat] = _repository.getHotPostsStream(cat).listen((data) {
        hotPostsMap[cat]!.value = data;
      });
    }
  }

  /// Schedule general refresh every 3 hours
  void _scheduleRefresh() {
    final now = DateTime.now();
    // Next 3-hour boundary
    final nextHour = (((now.hour ~/ 3) + 1) * 3) % 24;
    var nextRefresh = DateTime(now.year, now.month, now.day, nextHour);
    if (nextRefresh.isBefore(now) || nextRefresh.isAtSameMomentAs(now)) {
      nextRefresh = nextRefresh.add(const Duration(hours: 3));
    }
    final initialDelay = nextRefresh.difference(now);

    _initialTimer = Timer(initialDelay, () {
      _bindAllHotPosts();
      _periodicTimer = Timer.periodic(const Duration(hours: 3), (_) {
        _bindAllHotPosts();
      });
    });
  }

  void changeMainCategory(int index) {
    if (selectedMainCategoryIndex.value != index) {
      selectedMainCategoryIndex.value = index;
      selectedSubCategory.value = '전체';
      // Reset filters when switching main category
      isMyMeetupActive.value = false;
      isNearMeActive.value = false;
      _currentPosition = null;
      _bindPostsStream();

      // Reset scroll position to top when switching main tabs
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    }
  }

  void changeSubCategory(String tag) {
    if (selectedSubCategory.value != tag) {
      selectedSubCategory.value = tag;
      _bindPostsStream();
    }
  }

  /// 차단된 사용자의 게시글을 필터링해서 제외
  List<CommunityPost> _filterBlockedUsers(List<CommunityPost> postList) {
    if (!Get.isRegistered<AuthController>()) return postList;
    final auth = Get.find<AuthController>();
    if (auth.blockedUsers.isEmpty) return postList;
    return postList.where((post) => !auth.blockedUsers.contains(post.authorUid)).toList();
  }
}

/*
// ==========================================
// --- Legacy Controller Code (For reference)
// ==========================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/community_post.dart';
import '../../data/repositories/community_repository_impl.dart';
import 'community_constants.dart';

class CommunityController extends GetxController {
  final CommunityRepositoryImpl _repository = CommunityRepositoryImpl();
  
  // Selected Categories
  var selectedMainCategoryIndex = 0.obs;
  var selectedSubCategory = '전체'.obs;

  // Stream of Posts
  Rx<List<CommunityPost>> posts = Rx<List<CommunityPost>>([]);

  // Hot report posts (top 5 from '제보' category, last 3 days)
  Rx<List<CommunityPost>> hotReportPosts = Rx<List<CommunityPost>>([]);

  // ─── Search History ─────────────────────────────────────
  static const _historyKey = 'community_search_history';
  final searchHistory = <String>[].obs;

  // ─── Hot Report Refresh Timers ──────────────────────────
  Timer? _hotReportInitialTimer;
  Timer? _hotReportPeriodicTimer;

  // ... rest of legacy code mapping '전체', '제보' logic
}
*/
