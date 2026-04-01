import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';
import '../../config/app_secrets.dart';

/// Raw HTTP provider for Naver Local Search API.
class NaverApiProvider {
  static const String _clientId = AppSecrets.naverSearchClientId;
  static const String _clientSecret = AppSecrets.naverSearchClientSecret;
  static const String _baseUrl = 'https://openapi.naver.com/v1/search/local.json';

  /// Search places by keyword via Naver API.
  Future<List<PlaceModel>> searchPlaces(
    String query, {
    int display = 50,
    double? lat,
    double? lon,
  }) async {
    // User requested: "Sequential Loop + Stop on Duplicate"
    // API returns same 5 items if we go too fast or query is vague.
    // We fetch pages sequentially and stop if we see a duplicate title.

    List<PlaceModel> allPlaces = [];
    final seenTitles = <String>{};

    for (int i = 0; i < 20; i++) {
        int start = 1 + (i * 5);
        
        final pageResults = await _fetchPage(
            query,
            start: start,
            display: 5, 
            lat: lat,
            lon: lon
        );

        if (pageResults.isEmpty) break; // No more data

        bool foundDuplicate = false;
        for (var place in pageResults) {
            // Check signature (Title + Address is safer)
            final signature = '${place.title}_${place.roadAddress}';
            
            if (seenTitles.contains(signature)) {
                foundDuplicate = true;
                break; // Stop processing this page
            }
            seenTitles.add(signature);
            allPlaces.add(place);
        }

        if (foundDuplicate) {
            debugPrint("🛑 Duplicate found at page ${i+1}. Stopping loop early.");
            break; 
        }

        // Optional: Small delay to be nice to API
        await Future.delayed(const Duration(milliseconds: 50));
    }
    
    return allPlaces;
  }

  Future<List<PlaceModel>> _fetchPage(
    String query, {
    required int start,
    required int display,
    double? lat,
    double? lon,
  }) async {
    if (query.trim().isEmpty) return [];

    final queryParams = {
      'query': query,
      'display': display.toString(),
      'start': start.toString(),
      'sort': 'sim', 
    };
    
    // User requested to pass coordinates explicitly
    if (lat != null && lon != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lon.toString();
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    // debugPrint('🌐 API Req Page (start:$start): $uri'); 

    try {
      final response = await http.get(uri, headers: {
        'X-Naver-Client-Id': _clientId,
        'X-Naver-Client-Secret': _clientSecret,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        final mapped = items
            .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();
            
        debugPrint('🌐 API Page (start:$start): ${mapped.length} items. First: ${mapped.isNotEmpty ? mapped.first.title : "None"}');
        return mapped;
      } 
      return [];
    } catch (e) {
      debugPrint('❌ API Exception (Page $start): $e');
      return [];
    }
  }

  /// Single API call with sort:sim (accuracy). Naver API hard limit: 5 results.
  Future<List<PlaceModel>> searchSuggestions(
    String query, {
    int maxResults = 5,
    double? lat,
    double? lon,
  }) async {
    if (query.trim().isEmpty) return [];

    final queryParams = {
      'query': query,
      'display': maxResults.toString(),
      'start': '1',
      'sort': 'sim',  // Accuracy/similarity sort for suggestions
    };

    if (lat != null && lon != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lon.toString();
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    debugPrint('🔍 Suggestion API: $uri');

    try {
      final response = await http.get(uri, headers: {
        'X-Naver-Client-Id': _clientId,
        'X-Naver-Client-Secret': _clientSecret,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final total = data['total'] as int? ?? 0;
        final items = data['items'] as List<dynamic>? ?? [];

        final results = items
            .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
            .where((p) => p.latitude != 0 && p.longitude != 0)
            .toList();

        debugPrint('🔍 Suggestions: ${results.length} items (total available: $total)');
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('❌ Suggestion API error: $e');
      return [];
    }
  }
}
