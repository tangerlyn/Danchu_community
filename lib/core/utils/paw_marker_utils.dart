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
    double accumulated = 0;
    for (int i = 1; i < path.length; i++) {
        double dist = Geolocator.distanceBetween(
            path[i - 1].latitude, path[i - 1].longitude,
            path[i].latitude, path[i].longitude
        );
        accumulated += dist;
        if (accumulated >= intervalMeters) {
            double bearing = Geolocator.bearingBetween(
                path[i - 1].latitude, path[i - 1].longitude,
                path[i].latitude, path[i].longitude
            );
            paws.add({
              'position': path[i],
              'bearing': bearing,
            });
            accumulated = 0; // Reset accumulation after dropping a marker
        }
    }
    return paws;
  }

  static Future<void> placePawMarkers({
    required BuildContext context,
    required NaverMapController controller,
    required List<NLatLng> pathPoints,
    double intervalPx = 15,
    double pawSize = 30,
    double pawFontSize = 25,
    String idPrefix = "paw_marker",
  }) async {
      if (pathPoints.isEmpty || !context.mounted) return;
      
      final cameraPosition = await controller.getCameraPosition();
      final zoom = cameraPosition.zoom;
      final centerLat = cameraPosition.target.latitude;
      
      final intervalMeters = metersPerPixel(zoom, centerLat) * intervalPx;
      
      final pawPositions = calcPawPositions(pathPoints, intervalMeters);
      
      if (pawPositions.isEmpty || !context.mounted) return;

      final pawIconWidget = Icon(Icons.pets, size: pawFontSize, color: AppColors.deepBrown);

      final pawIcon = await NOverlayImage.fromWidget(
        widget: pawIconWidget,
        size: Size(pawSize, pawSize),
        context: context,
      );

      for (int i = 0; i < pawPositions.length; i++) {
        final data = pawPositions[i];
        final pawMarker = NMarker(
          id: "${idPrefix}_$i",
          position: data['position'] as NLatLng,
          icon: pawIcon,
          angle: data['bearing'] as double,
        );
        
        controller.addOverlay(pawMarker);
      }
  }
}
