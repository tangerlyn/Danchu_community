import 'package:flutter/foundation.dart';
import '../../domain/entities/place_entity.dart';

/// Data model extending PlaceEntity with JSON parsing for Naver API.
class PlaceModel extends PlaceEntity {
  PlaceModel({
    required super.title,
    required super.address,
    required super.roadAddress,
    required super.category,
    required super.telephone,
    required super.latitude,
    required super.longitude,
    super.distance,
  });

  /// Parse from Naver Local Search API JSON response.
  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    // Naver API returns mapx/mapy as scaled WGS84 (x10^7 approx)
    final rawX = int.tryParse(json['mapx']?.toString() ?? '0') ?? 0;
    final rawY = int.tryParse(json['mapy']?.toString() ?? '0') ?? 0;

    double lng, lat;
    if (rawX > 1000000) {
      lng = rawX / 10000000.0;
      lat = rawY / 10000000.0;
    } else {
      lng = rawX.toDouble();
      lat = rawY.toDouble();
    }
    
    // Log for debugging KATECH vs WGS84
    debugPrint('📍 Coords Debug: Raw($rawX, $rawY) -> Converted($lat, $lng) [Title: ${json['title']}]');
    
    // Validate Range for South Korea (Approx)
    // Lat: 33-39, Lon: 124-132
    if ((lat < 33.0 || lat > 39.0) || (lng < 124.0 || lng > 132.0)) {
       debugPrint('⚠️ Coords OUT OF RANGE (Korea): $lat, $lng');
    }

    // Strip HTML tags and decode HTML entities from title
    final cleanTitle = (json['title'] as String? ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Normalize Category
    var category = json['category'] as String? ?? '';
    if (category.contains('반려동물미용')) {
      category = '애견미용실';
    } else if (category.contains('애견카페')) {
      category = '애견카페';
    } else if (category.contains('반려동물호텔')) {
      category = '애견호텔';
    }

    return PlaceModel(
      title: cleanTitle,
      address: json['address'] ?? '',
      roadAddress: json['roadAddress'] ?? '',
      category: category,
      telephone: json['telephone'] ?? '',
      latitude: lat,
      longitude: lng,
    );
  }
}
