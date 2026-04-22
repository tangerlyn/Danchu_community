import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'walk_model.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../core/utils/paw_marker_utils.dart';
import '../../features/community/post_create_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../community/meetup_chat_page.dart';
import '../../data/repositories/friends_repository.dart';

class WalkDetailPage extends StatefulWidget {
  final Walk walk;

  const WalkDetailPage({super.key, required this.walk});

  @override
  State<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends State<WalkDetailPage> {
  NaverMapController? _mapController;
  List<NLatLng>? _cachedPathPoints;

  // 발자국 재배치를 위한 상태
  Set<String> _currentPawIds = {};
  double _initialZoom = 0;        // 기준선 (페이지 진입 시 고정)
  double _lastRenderedZoom = 0;   // 마지막으로 발자국을 그린 줌 값
  bool _isPlacingPaws = false;

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;

    final points = widget.walk.decodedRoutePoints;
    if (points.length >= 2) {
      final nLatLngPoints = points
          .map((p) => NLatLng(p[0], p[1]))
          .toList();

      if (!mounted) return;

      // Fit camera to show entire route with padding (consistent with summary page)
      final bounds = NLatLngBounds.from(nLatLngPoints);
      final cameraUpdate = NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.all(100),
      );
      cameraUpdate.setAnimation(animation: NCameraAnimation.none);
      controller.updateCamera(cameraUpdate);

      // Wait for camera to settle, then add paw markers
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      _cachedPathPoints = nLatLngPoints;
      final camPos = await controller.getCameraPosition();
      _initialZoom = camPos.zoom;
      _lastRenderedZoom = camPos.zoom;
      _currentPawIds = await PawMarkerUtils.placePawMarkers(
        context: context,
        controller: controller,
        pathPoints: nLatLngPoints,
      );
    }
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null || _isPlacingPaws) return;
    if (_cachedPathPoints == null || _cachedPathPoints!.length < 2) return;

    final camPos = await _mapController!.getCameraPosition();
    final currentZoom = camPos.zoom;

    // 목표 줌: 초기 줌이 하한선. 줌아웃 시 초기 줌 기준 발자국으로 복원.
    final targetZoom = currentZoom < _initialZoom ? _initialZoom : currentZoom;

    // 마지막으로 그린 줌과 0.3 미만 차이면 무시 (깜빡임 방지)
    if ((targetZoom - _lastRenderedZoom).abs() < 0.3) return;

    _isPlacingPaws = true;
    try {
      if (!mounted) return;
      _currentPawIds = await PawMarkerUtils.placePawMarkers(
        context: context,
        controller: _mapController!,
        pathPoints: _cachedPathPoints!,
        previousMarkerIds: _currentPawIds,
        zoomOverride: targetZoom,
      );
      _lastRenderedZoom = targetZoom;
    } finally {
      _isPlacingPaws = false;
    }
  }

  Widget _buildMarkerWidget(String text, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.mocha.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  NCameraPosition? _getInitialCameraPosition() {
    final points = widget.walk.decodedRoutePoints;
    if (points.length >= 2) {
      double minLat = points[0][0];
      double maxLat = points[0][0];
      double minLng = points[0][1];
      double maxLng = points[0][1];

      for (var p in points) {
        if (p[0] < minLat) minLat = p[0];
        if (p[0] > maxLat) maxLat = p[0];
        if (p[1] < minLng) minLng = p[1];
        if (p[1] > maxLng) maxLng = p[1];
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      return NCameraPosition(target: NLatLng(centerLat, centerLng), zoom: 15);
    }
    return null;
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
    }
    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.toStringAsFixed(0)} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(2)} km";
    }
  }

  @override
  Widget build(BuildContext context) {
    final walk = widget.walk;
    final hasRoute = walk.decodedRoutePoints.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('yyyy년 M월 d일', 'ko').format(walk.startTime)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Stats Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mocha.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DetailStat(
                  icon: Icons.access_time_rounded,
                  label: "시간",
                  value: DateFormat('a h:mm', 'ko').format(walk.startTime),
                  color: AppColors.latte,
                ),
                Container(height: 40, width: 1, color: AppColors.sand),
                _DetailStat(
                  icon: Icons.timer_outlined,
                  label: "소요 시간",
                  value: _formatDuration(walk.durationSeconds),
                  color: AppColors.deepBrown,
                ),
                Container(height: 40, width: 1, color: AppColors.sand),
                _DetailStat(
                  icon: Icons.directions_walk_rounded,
                  label: "거리",
                  value: _formatDistance(walk.distanceMeters),
                  color: AppColors.latte,
                ),
              ],
            ),
          ),

          // Dog name chips
          if (walk.dogNameList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: walk.dogNameList.map((name) => Chip(
                  avatar: const Icon(Icons.pets, size: 16, color: AppColors.deepBrown),
                  label: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  backgroundColor: AppColors.deepBrown.withOpacity(0.08),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ),

          // Route Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mocha.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: hasRoute
                  ? NaverMap(
                      options: NaverMapViewOptions(
                        customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
                        initialCameraPosition: _getInitialCameraPosition() ?? 
                            const NCameraPosition(
                              target: NLatLng(37.5547, 126.9707),
                              zoom: 15,
                            ),
                        liteModeEnable: true,
                        indoorEnable: true,
                        consumeSymbolTapEvents: false,
                        logoClickEnable: false,
                      ),
                      onMapReady: _onMapReady,
                      onCameraIdle: _onCameraIdle,
                    )
                  : Container(
                      color: AppColors.sand.withOpacity(0.3),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 48, color: AppColors.taupe),
                            SizedBox(height: 12),
                            Text(
                              "No route data available",
                              style: TextStyle(color: AppColors.taupe, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // Share Button
          if (hasRoute)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () => _shareCourse(context),
                  icon: const Icon(Icons.pets, size: 18),
                  label: const Text(
                    "이 코스 공유하기",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.deepBrown,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _shareCourse(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('산책 기록 공유',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.deepBrown),
                title: const Text('게시글로 쓰기',
                    style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareAsPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: AppColors.deepBrown),
                title: const Text('채팅방으로 공유',
                    style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareToChat(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _shareAsPost() {
    Get.to(() => const PostCreatePage(), arguments: {
      'mainCategory': '산책',
      'subCategory': '코스공유',
      'walkData': widget.walk,
    });
  }

  void _shareToChat(BuildContext context) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // 내가 참가한 모임 채팅방 목록
    final joinedChatsSnap = await FirebaseFirestore.instance
        .collection('users').doc(myUid)
        .collection('joined_chats')
        .get();

    // 친구 목록
    final friendsSnap = await FirebaseFirestore.instance
        .collection('users').doc(myUid)
        .collection('friends')
        .get();

    if (!context.mounted) return;

    // 채팅방 + 친구 목록 바텀시트
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareToChatSheet(
        walk: widget.walk,
        myUid: myUid,
        joinedChats: joinedChatsSnap.docs,
        friends: friendsSnap.docs,
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.taupe),
        ),
      ],
    );
  }
}

class _ShareToChatSheet extends StatefulWidget {
  final Walk walk;
  final String myUid;
  final List<QueryDocumentSnapshot> joinedChats;
  final List<QueryDocumentSnapshot> friends;

  const _ShareToChatSheet({
    required this.walk,
    required this.myUid,
    required this.joinedChats,
    required this.friends,
  });

  @override
  State<_ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends State<_ShareToChatSheet>
    with SingleTickerProviderStateMixin {
  bool _isSending = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _sendToMeetupChat(String postId, String postTitle) async {
    setState(() => _isSending = true);
    try {
      final walk = widget.walk;
      final routePoints = walk.decodedRoutePoints
          .map((p) => {'lat': p[0], 'lng': p[1]})
          .toList();
      final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(walk.startTime);
      final dogs = walk.dogNameList.isNotEmpty ? walk.dogNameList.join(', ') : null;

      // 내 닉네임 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(widget.myUid).get();
      final myNickname = userDoc.data()?['nickname'] ?? '알 수 없음';

      await FirebaseFirestore.instance
          .collection('community_posts').doc(postId)
          .collection('chat').add({
        'senderUid': widget.myUid,
        'senderNickname': myNickname,
        'message': '산책 기록을 공유했습니다.',
        'type': 'walk',
        'walkRoutePoints': routePoints,
        'walkDate': dateStr,
        if (dogs != null) 'walkDogNames': dogs,
        'imageUrls': [],
        'readBy': [widget.myUid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('⚠️ _sendToMeetupChat error: $e');
      Get.snackbar('잠깐!', '공유에 실패했어요 🐾');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendToDirectChat(String friendUid, String friendNickname) async {
    setState(() => _isSending = true);
    try {
      final walk = widget.walk;
      final routePoints = walk.decodedRoutePoints
          .map((p) => {'lat': p[0], 'lng': p[1]})
          .toList();
      final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(walk.startTime);
      final dogs = walk.dogNameList.isNotEmpty ? walk.dogNameList.join(', ') : null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(widget.myUid).get();
      final myNickname = userDoc.data()?['nickname'] ?? '알 수 없음';

      final chatId = FriendsRepository.getChatId(widget.myUid, friendUid);
      final msgRef = FirebaseFirestore.instance
          .collection('direct_chats').doc(chatId)
          .collection('messages').doc();

      await msgRef.set({
        'id': msgRef.id,
        'senderUid': widget.myUid,
        'senderNickname': myNickname,
        'message': '산책 기록을 공유했습니다.',
        'type': 'walk',
        'walkRoutePoints': routePoints,
        'walkDate': dateStr,
        if (dogs != null) 'walkDogNames': dogs,
        'imageUrls': [],
        'readBy': [widget.myUid],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // direct_chats 문서 lastMessage 업데이트
      await FirebaseFirestore.instance
          .collection('direct_chats').doc(chatId)
          .set({
        'participants': [widget.myUid, friendUid],
        'lastMessage': '산책 기록을 공유했습니다.',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('⚠️ _sendToDirectChat error: $e');
      Get.snackbar('잠깐!', '공유에 실패했어요 🐾');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('채팅방 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.deepBrown)),
          const SizedBox(height: 12),

          // ── 탭 바 ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.sand.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.deepBrown,
              unselectedLabelColor: AppColors.taupe,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: '모임  ${widget.joinedChats.length}'),
                Tab(text: '친구  ${widget.friends.length}'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── 탭 콘텐츠 ──
          Expanded(
            child: _isSending
                ? const Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // 모임 탭
                      widget.joinedChats.isEmpty
                          ? const Center(
                              child: Text('참가 중인 모임이 없습니다.',
                                  style: TextStyle(color: AppColors.taupe, fontSize: 14)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: widget.joinedChats.length,
                              itemBuilder: (context, index) {
                                final doc = widget.joinedChats[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final postId = doc.id;
                                final title = data['chatRoomName'] ?? data['postTitle'] ?? '모임 채팅';
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.sand.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.people_outline, color: AppColors.deepBrown, size: 20),
                                  ),
                                  title: Text(title,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
                                  onTap: () => _sendToMeetupChat(postId, title),
                                );
                              },
                            ),

                      // 친구 탭
                      widget.friends.isEmpty
                          ? const Center(
                              child: Text('친구가 없습니다.',
                                  style: TextStyle(color: AppColors.taupe, fontSize: 14)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: widget.friends.length,
                              itemBuilder: (context, index) {
                                final doc = widget.friends[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final friendUid = doc.id;
                                final nickname = data['nickname'] ?? '알 수 없음';
                                final profileImageUrl = data['profileImageUrl'] ?? '';
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.sand,
                                    backgroundImage: profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : null,
                                    child: profileImageUrl.isEmpty
                                        ? ClipOval(child: Image.asset('assets/icon/app_icon3.png', fit: BoxFit.cover))
                                        : null,
                                  ),
                                  title: Text(nickname,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepBrown)),
                                  onTap: () => _sendToDirectChat(friendUid, nickname),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
