import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import '../../core/utils/paw_marker_utils.dart';

class WalkMapThumbnail extends StatelessWidget {
  final ChatMessage msg;

  const WalkMapThumbnail({super.key, required this.msg});

  NCameraPosition? _getInitialCameraPosition() {
    final points = msg.walkRoutePoints;
    if (points != null && points.length >= 2) {
      double minLat = points[0]['lat']!;
      double maxLat = points[0]['lat']!;
      double minLng = points[0]['lng']!;
      double maxLng = points[0]['lng']!;

      for (var p in points) {
        if (p['lat']! < minLat) minLat = p['lat']!;
        if (p['lat']! > maxLat) maxLat = p['lat']!;
        if (p['lng']! < minLng) minLng = p['lng']!;
        if (p['lng']! > maxLng) maxLng = p['lng']!;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      return NCameraPosition(target: NLatLng(centerLat, centerLng), zoom: 14);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (msg.walkRoutePoints == null || msg.walkRoutePoints!.length < 2) {
      return Container(
        color: AppColors.sand.withOpacity(0.3),
        child: const Center(
          child: Icon(Icons.map_outlined, color: AppColors.taupe),
        ),
      );
    }
    
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: _getInitialCameraPosition() ?? 
            const NCameraPosition(target: NLatLng(37.5547, 126.9707), zoom: 14),
        liteModeEnable: true,
        indoorEnable: false,
        consumeSymbolTapEvents: false,
        logoClickEnable: false,
        scrollGesturesEnable: false,
        zoomGesturesEnable: false,
        tiltGesturesEnable: false,
        rotationGesturesEnable: false,
        stopGesturesEnable: false,
      ),
      onMapReady: (controller) async {
        final points = msg.walkRoutePoints!;
        final nLatLngPoints = points.map((p) => NLatLng(p['lat']!, p['lng']!)).toList();
        
        final pathOverlay = NPathOverlay(
          id: 'walk_path_thumbnail_${msg.id}',
          coords: nLatLngPoints,
          color: AppColors.deepBrown,
          width: 4,
          outlineColor: Colors.white,
          outlineWidth: 1,
        );
        controller.addOverlay(pathOverlay);

        await Future.delayed(const Duration(milliseconds: 300));
        final bounds = NLatLngBounds.from(nLatLngPoints);
        final cameraUpdate = NCameraUpdate.fitBounds(
          bounds,
          padding: const EdgeInsets.all(24),
        );
        cameraUpdate.setAnimation(animation: NCameraAnimation.none);
        controller.updateCamera(cameraUpdate);
      },
    );
  }
}

class WalkRouteViewPage extends StatefulWidget {
  final ChatMessage msg;

  const WalkRouteViewPage({super.key, required this.msg});

  @override
  State<WalkRouteViewPage> createState() => _WalkRouteViewPageState();
}

class _WalkRouteViewPageState extends State<WalkRouteViewPage> {
  NaverMapController? _mapController;
  Set<String> _currentPawIds = {};
  double _initialZoom = 0;
  double _lastRenderedZoom = 0;
  bool _isPlacingPaws = false;

  NCameraPosition? _getInitialCameraPosition() {
    final points = widget.msg.walkRoutePoints;
    if (points != null && points.length >= 2) {
      double minLat = points[0]['lat']!;
      double maxLat = points[0]['lat']!;
      double minLng = points[0]['lng']!;
      double maxLng = points[0]['lng']!;

      for (var p in points) {
        if (p['lat']! < minLat) minLat = p['lat']!;
        if (p['lat']! > maxLat) maxLat = p['lat']!;
        if (p['lng']! < minLng) minLng = p['lng']!;
        if (p['lng']! > maxLng) maxLng = p['lng']!;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      return NCameraPosition(target: NLatLng(centerLat, centerLng), zoom: 15);
    }
    return null;
  }

  void _onMapReady(NaverMapController controller) async {
    _mapController = controller;

    final points = widget.msg.walkRoutePoints;
    if (points != null && points.length >= 2) {
      final nLatLngPoints = points.map((p) => NLatLng(p['lat']!, p['lng']!)).toList();

      if (!mounted) return;

      final bounds = NLatLngBounds.from(nLatLngPoints);
      final cameraUpdate = NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.all(80),
      );
      cameraUpdate.setAnimation(animation: NCameraAnimation.none);
      controller.updateCamera(cameraUpdate);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      
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
    final points = widget.msg.walkRoutePoints;
    if (points == null || points.length < 2) return;

    final nLatLngPoints = points.map((p) => NLatLng(p['lat']!, p['lng']!)).toList();
    
    final camPos = await _mapController!.getCameraPosition();
    final currentZoom = camPos.zoom;

    final targetZoom = currentZoom < _initialZoom ? _initialZoom : currentZoom;
    if ((targetZoom - _lastRenderedZoom).abs() < 0.3) return;

    _isPlacingPaws = true;
    try {
      if (!mounted) return;
      _currentPawIds = await PawMarkerUtils.placePawMarkers(
        context: context,
        controller: _mapController!,
        pathPoints: nLatLngPoints,
        previousMarkerIds: _currentPawIds,
        zoomOverride: targetZoom,
      );
      _lastRenderedZoom = targetZoom;
    } finally {
      _isPlacingPaws = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.msg.senderNickname}님의 산책 기록'),
        centerTitle: true,
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
          initialCameraPosition: _getInitialCameraPosition() ?? 
              const NCameraPosition(target: NLatLng(37.5547, 126.9707), zoom: 15),
          liteModeEnable: false,
          indoorEnable: true,
        ),
        onMapReady: _onMapReady,
        onCameraIdle: _onCameraIdle,
      ),
    );
  }
}
