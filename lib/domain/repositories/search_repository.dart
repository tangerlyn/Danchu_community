import '../entities/place_entity.dart';

/// Abstract repository for place search operations.
/// Implemented in the data layer.
abstract class SearchRepository {
  /// Search places by keyword.
  /// If [lat]/[lon] are provided, search near that location (by reverse geocoding address).
  /// Otherwise, uses current GPS location.
  Future<List<PlaceEntity>> searchPlaces(
    String query, {
    int display = 20,
    double? lat,
    double? lon,
    // Boundary & Zoom for Smart Search
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    double? zoomLevel,
    bool strictBounds = false,
  });

  /// Lightweight search for autocomplete suggestions (max 5 per Naver API).
  Future<List<PlaceEntity>> searchSuggestions(
    String query, {
    int maxResults = 5,
    double? lat,
    double? lon,
  });

  /// Search for nearby pet-related places across all categories.
  /// If [lat]/[lon] provided, search near there.
  Future<List<PlaceEntity>> searchNearbyPetPlaces({
    double? lat, 
    double? lon,
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    double? zoomLevel,
    bool strictBounds = false,
  });

  /// Get simplified region name (e.g. "Namgajwa-dong" or "Seodaemun-gu") for coordinates.
  /// Used to append to search query.
  Future<String?> getRegionName(double lat, double lon);

  /// Load search history from local storage.
  Future<List<String>> loadSearchHistory();

  /// Add a search query to history.
  Future<void> addSearchHistory(String query);

  /// Remove a single history item.
  Future<void> removeSearchHistory(String query);

  /// Clear all search history.
  Future<void> clearSearchHistory();
}
