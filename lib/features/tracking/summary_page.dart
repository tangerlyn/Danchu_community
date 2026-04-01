import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:math';
import '../../features/history/database_helper.dart';
import '../../features/history/walk_model.dart';
import 'package:geolocator/geolocator.dart';
import '../main_screen.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../features/community/post_create_page.dart';
import '../../core/utils/paw_marker_utils.dart';

class SummaryPage extends StatefulWidget {
  final int durationSeconds;
  final double distanceMeters;
  final List<NLatLng> pathPoints;
  final List<String> dogNames;

  const SummaryPage({
    super.key,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.pathPoints,
    this.dogNames = const [],
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    
    // Draw the full path
    if (widget.pathPoints.length >= 2) {
      /*
      final pathOverlay = NPathOverlay(
        id: "summary_path",
        coords: widget.pathPoints,
        width: 5,
        color: AppColors.sand,
        outlineColor: AppColors.white,
      );
      controller.addOverlay(pathOverlay);
      */
      
      if (!mounted) return;

      /*
      final startIcon = await NOverlayImage.fromWidget(
        widget: _buildMarkerWidget(16),
        size: const Size(16, 16),
        context: context,
      );

      final endIcon = await NOverlayImage.fromWidget(
        widget: _buildMarkerWidget(16),
        size: const Size(16, 16),
        context: context,
      );

      final startMarker = NMarker(
        id: "start_marker",
        position: widget.pathPoints.first,
        icon: startIcon,
      );
      startMarker.setAnchor(const NPoint(0.5, 0.5));
      controller.addOverlay(startMarker);

      final endMarker = NMarker(
        id: "end_marker",
        position: widget.pathPoints.last,
        icon: endIcon,
      );
      endMarker.setAnchor(const NPoint(0.5, 0.5));
      controller.addOverlay(endMarker);
      */

      // Fit bounds to show the whole path with padding
      final bounds = NLatLngBounds.from(widget.pathPoints);
      controller.updateCamera(
        NCameraUpdate.fitBounds(
          bounds,
          padding: const EdgeInsets.all(100),
        ),
      );

      // Wait for camera to settle, then add paw markers
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await PawMarkerUtils.placePawMarkers(
        context: context,
        controller: controller,
        pathPoints: widget.pathPoints,
      );
    }
  }

  Future<void> _saveWalk({bool share = false}) async {
    // Encode path points to JSON string
    final routePointsJson = jsonEncode(
      widget.pathPoints.map((p) => [p.latitude, p.longitude]).toList(),
    );

    final walk = Walk(
      startTime: DateTime.now().subtract(Duration(seconds: widget.durationSeconds)),
      durationSeconds: widget.durationSeconds,
      distanceMeters: widget.distanceMeters,
      routePoints: routePointsJson,
      dogNames: widget.dogNames.isNotEmpty ? widget.dogNames.join(',') : null,
    );
    
    await DatabaseHelper.instance.create(walk);
    
    if (mounted) {
      if (share) {
        final List<Map<String, double>> routePoints = widget.pathPoints.map((p) => {
          'lat': p.latitude,
          'lng': p.longitude,
        }).toList();

        // Close SummaryPage
        Navigator.pop(context); 

        // Generate walk summary string
        final dateStr = DateFormat('yyyy년 M월 d일', 'ko').format(DateTime.now());
        final dogs = widget.dogNames.isNotEmpty ? widget.dogNames.join(', ') : '없음';
        final distanceKm = widget.distanceMeters / 1000;
        final distanceStr = distanceKm < 1 ? "${distanceKm.toStringAsFixed(1)}km" : "${distanceKm.toStringAsFixed(2)}km";
        final minutes = widget.durationSeconds ~/ 60;
        final durationStr = "${minutes}분";
        final walkSummary = "$dateStr · $distanceStr · $durationStr";

        // Schedule navigation to PostCreatePage safely after the current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(() => const PostCreatePage(), arguments: {
            'mainCategory': '산책',
            'subCategory': '코스공유',
            'routePoints': routePoints,
            'walkSummary': walkSummary,
          });
        });
      } else {
        Navigator.pop(context); // Go back to Home
        // Switch to History tab
        MainScreen.currentState?.switchToTab(1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('산책이 기록되었습니다! 🐾')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("오늘의 산책"),
        automaticallyImplyLeading: false, // Don't allow going back without saving/discarding
      ),
      body: Column(
        children: [
          // 1. Map Snapshot
          Expanded(
            flex: 5,
            child: NaverMap(
              options: const NaverMapViewOptions(
                customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
                liteModeEnable: true, // Use lite mode for static view
                indoorEnable: true,
                consumeSymbolTapEvents: false,
                logoClickEnable: false,
              ),
              onMapReady: _onMapReady,
            ),
          ),
          
          // 2. Stats & Action
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: AppColors.mocha.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.deepBrown),
                        children: [
                          const TextSpan(text: "오늘도 산책 완료! "),
                          const WidgetSpan(
                            child: Icon(Icons.pets, size: 24, color: AppColors.deepBrown),
                            alignment: PlaceholderAlignment.middle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Stats Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat(
                          label: "시간",
                          value: _formatDuration(widget.durationSeconds),
                          icon: Icons.timer,
                          color: AppColors.deepBrown,
                        ),
                        _SummaryStat(
                          label: "거리",
                          value: _formatDistance(widget.distanceMeters),
                          icon: Icons.directions_walk,
                          color: AppColors.deepBrown,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                  
                  // Bottom Buttons: Share, Save to History
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => _saveWalk(share: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.deepBrown,
                              side: const BorderSide(color: AppColors.deepBrown),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("산책자랑 글쓰기", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: () => _saveWalk(share: false),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.deepBrown,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("기록만 저장", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("기록 삭제"),
                            content: const Text("이 산책 기록을 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("취소"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx); // Close dialog
                                  Navigator.pop(context); // Go back to Home
                                },
                                child: const Text("삭제", style: TextStyle(color: AppColors.deepBrown)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text("산책 삭제하기", style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: AppColors.latte),
        ),
      ],
    );
  }
}
