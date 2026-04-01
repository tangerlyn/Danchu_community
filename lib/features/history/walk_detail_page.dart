import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'walk_model.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../core/utils/paw_marker_utils.dart';
import '../../features/community/post_create_page.dart';

class WalkDetailPage extends StatefulWidget {
  final Walk walk;

  const WalkDetailPage({super.key, required this.walk});

  @override
  State<WalkDetailPage> createState() => _WalkDetailPageState();
}

class _WalkDetailPageState extends State<WalkDetailPage> {
  Future<void> _onMapReady(NaverMapController controller) async {
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
      
      await PawMarkerUtils.placePawMarkers(
        context: context,
        controller: controller,
        pathPoints: nLatLngPoints,
      );
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
    final walk = widget.walk;
    final dateStr = DateFormat('yyyy년 M월 d일', 'ko').format(walk.startTime);
    final dogs = walk.dogNameList.isNotEmpty ? walk.dogNameList.join(', ') : '없음';
    
    // Custom formatting for share content to match user request: "0.5km · 10분"
    final distanceKm = walk.distanceMeters / 1000;
    final distanceStr = distanceKm < 1 ? "${distanceKm.toStringAsFixed(1)}km" : "${distanceKm.toStringAsFixed(2)}km";
    
    final minutes = walk.durationSeconds ~/ 60;
    final durationStr = "${minutes}분";

    final walkSummary = "$dateStr · $distanceStr · $durationStr";

    final List<Map<String, double>> routePoints = walk.decodedRoutePoints.map((p) => {
      'lat': p[0],
      'lng': p[1],
    }).toList();
    Get.to(() => const PostCreatePage(), arguments: {
      'mainCategory': '산책',
      'subCategory': '코스공유',
      'routePoints': routePoints,
      'walkSummary': walkSummary,
    });
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
