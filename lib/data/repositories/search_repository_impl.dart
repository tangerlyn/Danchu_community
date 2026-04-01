import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/place_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../providers/naver_api_provider.dart';

/// Concrete implementation of [SearchRepository].
/// Uses [NaverApiProvider] for API calls, [Geolocator] for location,
/// and [SharedPreferences] for search history persistence.
class SearchRepositoryImpl implements SearchRepository {
  final NaverApiProvider _apiProvider;

  SearchRepositoryImpl({required NaverApiProvider apiProvider})
      : _apiProvider = apiProvider;

  static const _historyKey = 'search_history';
  static const _petCategories = [
    '동물병원', 
    '애견용품', 
    '애견유치원',
    '반려동물미용',
    '애견카페',
    '반려동물호텔'
  ];

  // ─── Search ─────────────────────────────────────────────

  @override
  Future<List<PlaceEntity>> searchPlaces(
    String query, {
    int display = 50, 
    double? lat,
    double? lon,
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    double? zoomLevel,
    bool strictBounds = false,
  }) async {
    // 1. Raw Query Search (No geocoding prefix)
    // User requested explicit region handling via reverse geocoding now.
    // We do NOT strip region names anymore.
    String finalQuery = query;
        
    debugPrint('🔎 Searching Raw: "$finalQuery" (Display: $display, Lat/Lon: $lat, $lon, Strict: $strictBounds)');

    // 2. Call API with Raw Query + Coordinates (Provider now fetches 100 items)
    final results = await _apiProvider.searchPlaces(
      finalQuery, 
      display: 5, // Provider ignores this and does 20x5 loops
      lat: lat, 
      lon: lon
    );

    // 3. Strict Bounds Filtering (User Request)
    // "Delete anything outside visible bounds" ONLY if strictBounds is true
    List<PlaceEntity> filteredResults = [];
    if (strictBounds && minLat != null && maxLat != null && minLon != null && maxLon != null) {
       filteredResults = results.where((p) {
          return p.latitude >= minLat && p.latitude <= maxLat &&
                 p.longitude >= minLon && p.longitude <= maxLon;
       }).toList();
       debugPrint('✂️ Strict Filter: ${results.length} -> ${filteredResults.length} items (Bounds: $minLat~$maxLat, $minLon~$maxLon)');
    } else {
       // Keep all results for Global Search
       filteredResults = results;
    }

    // 4. Compute distances
    await _computeDistances(filteredResults, lat: lat, lon: lon);

    // 5. Sort by distance (Nearest first)
    filteredResults.sort((a, b) => a.distance.compareTo(b.distance));
    
    return filteredResults;
  }

  @override
  Future<List<PlaceEntity>> searchSuggestions(
    String query, {
    int maxResults = 5,
    double? lat,
    double? lon,
  }) async {
    final results = await _apiProvider.searchSuggestions(
      query,
      maxResults: maxResults,
      lat: lat,
      lon: lon,
    );

    // Convert PlaceModel → PlaceEntity
    final entities = results.map((m) => PlaceEntity(
      title: m.title,
      address: m.address,
      roadAddress: m.roadAddress,
      category: m.category,
      latitude: m.latitude,
      longitude: m.longitude,
      telephone: m.telephone,
    )).toList();

    // Compute distances for UI display, but do NOT sort — preserve API's sort:sim order
    await _computeDistances(entities, lat: lat, lon: lon);
    return entities;
  }

  @override
  Future<List<PlaceEntity>> searchNearbyPetPlaces({
    double? lat, 
    double? lon,
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    double? zoomLevel,
    bool strictBounds = false,
  }) async {
    // Parallelize categories * strategies
    // Instead of calling searchPlaces loop, we can just call searchPlaces for each cat.
    // searchPlaces execution is already optimized.
    
    final futures = _petCategories.map((cat) => searchPlaces(
          cat, 
          display: 50, // Force 50
          lat: lat, 
          lon: lon,
          minLat: minLat,
          minLon: minLon,
          maxLat: maxLat,
          maxLon: maxLon,
          zoomLevel: zoomLevel,
          strictBounds: strictBounds,
        ));
    
    final results = await Future.wait(futures);
    
    // Deduplicate across categories? (Rare but possible if Keywords overlap)
    final Map<String, PlaceEntity> uniqueResults = {};
    for (final list in results) {
      for (final place in list) {
         final key = '${place.title}_${place.address}';
         uniqueResults[key] = place;
      }
    }
    
    final allPlaces = uniqueResults.values.toList();
    
    // Re-sort all combined
    if (lat != null && lon != null) {
      // Recalculate sort because merge might have mixed order
       allPlaces.sort((a, b) => a.distance.compareTo(b.distance));
    }
    
    return allPlaces;
  }

  /// Compute straight-line distance from origin to each place.
  /// If [lat]/[lon] not provided, uses current GPS position.
  Future<void> _computeDistances(
    List<PlaceEntity> places, {
    double? lat,
    double? lon,
  }) async {
    double originLat;
    double originLon;

    if (lat != null && lon != null) {
      originLat = lat;
      originLon = lon;
    } else {
      debugPrint('⚠️ No origin provided for distance calculation. Skipping.');
      return;
    }

    for (final place in places) {
      place.distance = _haversineDistance(
        originLat, originLon,
        place.latitude, place.longitude,
      );
    }
  }

  /// Haversine formula for distance between two coordinates in meters.
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  @override
  Future<String?> getRegionName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Prioritize: subLocality (Dong) > locality (Gu) > administrativeArea (City)
        // Example: 'Yeomri-dong' or 'Mapo-gu'
        final region = place.subLocality?.isNotEmpty == true 
            ? place.subLocality 
            : (place.locality?.isNotEmpty == true ? place.locality : place.thoroughfare);
            
        debugPrint('📍 Reverse Geocoding: ($lat, $lon) -> $region');
        return region;
      }
    } catch (e) {
      debugPrint('⚠️ Reverse Geocoding Failed: $e');
    }
    return null;
  }

  // ─── History ────────────────────────────────────────────

  @override
  Future<List<String>> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  @override
  Future<void> addSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    history.insert(0, query);
    if (history.length > 20) history.removeLast();
    await prefs.setStringList(_historyKey, history);
  }

  @override
  Future<void> removeSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_historyKey, history);
  }

  @override
  Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, []);
  }
}
