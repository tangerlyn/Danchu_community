import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_colors.dart';

class PawMarkerUtils {
  static double metersPerPixel(double zoomLevel, double latitude) {
    return 156543.03392 * cos(latitude * pi / 180) / pow(2, zoomLevel);
  }

  static List<Map<String, dynamic>> calcPawPositions(List<NLatLng> path, double intervalMeters) {
    List<Map<String, dynamic>> paws = [];
    if (path.length < 2) return paws;

    double accumulated = 0;
    int lastPawIndex = 0;

    for (int i = 1; i < path.length; i++) {
      double dist = Geolocator.distanceBetween(
          path[i - 1].latitude, path[i - 1].longitude,
          path[i].latitude, path[i].longitude
      );
      accumulated += dist;
      if (accumulated >= intervalMeters) {
        double bearing = Geolocator.bearingBetween(
            path[lastPawIndex].latitude, path[lastPawIndex].longitude,
            path[i].latitude, path[i].longitude
        );
        bearing = (bearing + 360) % 360;

        paws.add({
          'position': path[i],
          'bearing': bearing,
        });
        accumulated = 0;
        lastPawIndex = i;
      }
    }
    return paws;
  }

  /// 발자국 마커를 지도에 배치한다.
  /// [previousMarkerIds]가 주어지면 해당 ID의 마커들을 먼저 제거한 후 새로 그린다.
  /// [zoomOverride]가 주어지면 현재 카메라 줌 대신 해당 값으로 간격을 계산한다.
  /// 반환값: 이번에 그린 마커들의 ID 집합.
  static Future<Set<String>> placePawMarkers({
    required BuildContext context,
    required NaverMapController controller,
    required List<NLatLng> pathPoints,
    double intervalPx = 15,
    double pawSize = 24,
    double pawFontSize = 20,
    String idPrefix = "paw_marker",
    Set<String>? previousMarkerIds,
    double? zoomOverride,
  }) async {
    if (pathPoints.isEmpty || !context.mounted) return {};

    // 1. 기존 마커 제거
    if (previousMarkerIds != null && previousMarkerIds.isNotEmpty) {
      try {
        await controller.clearOverlays(type: NOverlayType.marker);
      } catch (_) {
        // 실패 시 무시
      }
    }

    // 2. 줌 결정: override가 있으면 그걸 쓰고, 없으면 현재 카메라 줌
    final cameraPosition = await controller.getCameraPosition();
    final zoom = zoomOverride ?? cameraPosition.zoom;
    final centerLat = cameraPosition.target.latitude;

    final intervalMeters = metersPerPixel(zoom, centerLat) * intervalPx;

    final pawPositions = calcPawPositions(pathPoints, intervalMeters);

    if (pawPositions.isEmpty || !context.mounted) return {};

    // 3. 아이콘 생성
    final pawIconWidget = Icon(Icons.pets, size: pawFontSize, color: AppColors.deepBrown);
    final pawIcon = await NOverlayImage.fromWidget(
      widget: pawIconWidget,
      size: Size(pawSize, pawSize),
      context: context,
    );

    // 4. 마커 배치
    final Set<String> newIds = {};
    for (int i = 0; i < pawPositions.length; i++) {
      final data = pawPositions[i];
      final id = "${idPrefix}_$i";
      final pawMarker = NMarker(
        id: id,
        position: data['position'] as NLatLng,
        icon: pawIcon,
        angle: data['bearing'] as double,
        isFlat: true,
      );
      controller.addOverlay(pawMarker);
      newIds.add(id);
    }

    return newIds;
  }
}
