import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';

import '../../../domain/entities/place_entity.dart';
import '../../../domain/repositories/search_repository.dart';
import '../../../../features/profile/bookmarked_places_page.dart';

/// GetX Controller for the Home (Map) screen.
/// Manages search, categories, markers, and all UI state reactively.
class HomeController extends GetxController {
  final SearchRepository repository;
  HomeController({required this.repository});

  // ─── Map ─────────────────────────────────────────────────
  NaverMapController? mapController;
  final categoryIcons = <String, NOverlayImage>{};
  final softSalmonCategoryIcons = <String, NOverlayImage>{};
  final bookmarkIcons = <String, NOverlayImage>{};

  // ─── Reactive State ──────────────────────────────────────

  final searchResults = <PlaceEntity>[].obs;
  final searchSuggestions = <PlaceEntity>[].obs; // For autocomplete only
  final nearbyPlaces = <PlaceEntity>[].obs;
  final searchHistory = <String>[].obs;
  final bookmarkedPlaces = <PlaceEntity>[].obs;

  final selectedPlace = Rxn<PlaceEntity>();
  final selectedCategory = ''.obs;

  final isSearching = false.obs;
  final showBottomSheet = false.obs;
  final showDropdown = false.obs;
  final showSearchInMapButton = false.obs;
  final hideCategories = false.obs;
  final isSearchFocused = false.obs;
  
  // Track active search context
  final currentSearchQuery = ''.obs;

  // ─── Text Controller ────────────────────────────────────
  late TextEditingController searchController;
  late FocusNode searchFocusNode;
  final sheetController = DraggableScrollableController();
  Timer? _debounce;
  StreamSubscription? _bookmarkSubscription;

  // ─── Categories ─────────────────────────────────────────
  static const categories = ['동물병원', '애견용품', '애견유치원', '애견미용실', '애견카페', '애견호텔'];
  
  // Mapping category -> Naver Search Keyword
  final Map<String, String> _categoryKeywords = {
    '동물병원': '동물병원',
    '애견용품': '애견용품',
    '애견유치원': '애견유치원',
    '애견미용실': '반려동물미용',
    '애견카페': '애견카페',
    '애견호텔': '반려동물호텔',
  };

  // ─── Lifecycle ──────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
    _loadHistory();
    // Listen to focus changes on the search field
    searchFocusNode.addListener(_onSearchFocusChanged);
    
    // Refresh markers when selection changes
    ever(selectedPlace, (_) {
      _updateMarkers();
    });

    // Refresh markers based on search query visibility rules
    ever(currentSearchQuery, (_) => _updateMarkers());

    _listenToBookmarks();
  }

  void _onSearchFocusChanged() {
    isSearchFocused.value = searchFocusNode.hasFocus;
    if (searchFocusNode.hasFocus) {
      // Close any open bottom sheet to prevent overlap
      showBottomSheet.value = false;
      searchResults.clear();
      // Show recent searches, hide categories
      hideCategories.value = true;
      _loadHistory();
    } else {
      // Restore categories if not showing bottom sheet
      if (!showBottomSheet.value && selectedPlace.value == null) {
        hideCategories.value = false;
      }
    }
  }

  void _listenToBookmarks() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _bookmarkSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('bookmarked_places')
        .snapshots()
        .listen((snapshot) {
      _updateBookmarkMarkers(snapshot.docs);
    });
  }

  void _updateBookmarkMarkers(List<DocumentSnapshot> docs) {
    bookmarkedPlaces.value = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return PlaceEntity(
        id: data['placeId'] ?? doc.id,
        title: data['placeName'] ?? '',
        address: data['address'] ?? '',
        roadAddress: data['address'] ?? '', // Match address to ensure consistent ID calc
        category: data['category'] ?? '',
        telephone: '',
        latitude: data['lat'] ?? 0.0,
        longitude: data['lng'] ?? 0.0,
      );
    }).toList();
    _updateMarkers();
  }

  void _updateMarkers() {
    mapController?.clearOverlays();
    if (currentSearchQuery.value.isEmpty && selectedCategory.value.isEmpty) {
      _showBookmarkMarkers();
    }
    showCategoryMarkers();
  }

  void _showBookmarkMarkers() {
    if (mapController == null || bookmarkedPlaces.isEmpty || bookmarkIcons.isEmpty) return;

    for (int i = 0; i < bookmarkedPlaces.length; i++) {
      final place = bookmarkedPlaces[i];
      // 카테고리 무관하게 항상 북마크 default 아이콘 사용
      final icon = bookmarkIcons['default']!;

      final marker = NMarker(
        id: 'bookmark_${place.id}',
        position: NLatLng(place.latitude, place.longitude),
        icon: icon,
      );
      marker.setOnTapListener((_) => onPlaceTapped(place));
      mapController?.addOverlay(marker);
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _bookmarkSubscription?.cancel();
    searchFocusNode.removeListener(_onSearchFocusChanged);
    searchController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  // ─── Map Callbacks ──────────────────────────────────────

  void onMapReady(NaverMapController controller) {
    mapController = controller;
    debugPrint("Naver Map Ready");
    
    // Enable location tracking to start at user's position
    mapController?.setLocationTrackingMode(NLocationTrackingMode.follow);
    
    // 카테고리 아이콘과 북마크 아이콘 모두 초기화 완료 후 마커 그리기
    Future.wait([
      _initCategoryMarkers(),
      _initBookmarkMarkers(),
    ]).then((_) {
      // 지도 준비 완료 후 북마크 마커 복원
      if (bookmarkedPlaces.isNotEmpty) {
        _showBookmarkMarkers();
      }
    });
  }

  void onCameraChange(NCameraUpdateReason reason) {
    if (isClosed) return;
    // Only show "현 지도에서 검색" when search context is active (query or category)
    // AND a place is NOT currently selected
    final hasActiveContext = currentSearchQuery.value.isNotEmpty || 
                             (selectedCategory.value.isNotEmpty && selectedCategory.value != '전체');
    
    if (hasActiveContext &&
        !showSearchInMapButton.value &&
        selectedPlace.value == null && 
        reason == NCameraUpdateReason.gesture) {
      showSearchInMapButton.value = true;
    }
  }

  void onMapTapped(NPoint point, NLatLng latLng) {
    if (isClosed) return;
    if (isSearchFocused.value) {
      searchFocusNode.unfocus();
      isSearchFocused.value = false;
      showDropdown.value = false;
      
      // Also ensure categories are shown if no place selected
      if (selectedPlace.value == null) {
        hideCategories.value = false;
      }
    }
  }

  // ─── Category Markers ───────────────────────────────────

  Future<void> _initCategoryMarkers() async {
    final context = Get.context;
    if (context == null) return;

    final configs = <String, (dynamic, Color)>{
      'default': (Icons.pets, AppColors.deepBrown),
      'hospital': (Icons.local_hospital, AppColors.deepBrown),
      'store': (Icons.shopping_bag, AppColors.mocha),
      'playground': (Icons.school, AppColors.latte),
      'beauty': (Icons.content_cut, AppColors.latte),
      'cafe': (Icons.coffee, AppColors.taupe),
      'hotel': (Icons.hotel, AppColors.sand),
    };
    for (final entry in configs.entries) {
      categoryIcons[entry.key] = await NOverlayImage.fromWidget(
        widget: _buildMarkerIconWidget(entry.value.$1, entry.value.$2),
        size: const Size(40, 40),
        context: context,
      );

      softSalmonCategoryIcons[entry.key] = await NOverlayImage.fromWidget(
        widget: _buildMarkerIconWidget(entry.value.$1, AppColors.softSalmon, isHighlighted: true),
        size: const Size(40, 40),
        context: context,
      );
    }
    debugPrint("✅ Category marker icons built (Normal & Soft Salmon)");
  }

  Future<void> _initBookmarkMarkers() async {
    final context = Get.context;
    if (context == null) return;

    final configs = <String, (dynamic, Color)>{
      'default': (Icons.bookmark, const Color(0xFF5C3D2E)),
      'hospital': (Icons.local_hospital, const Color(0xFF5C3D2E)),
      'store': (Icons.shopping_bag, const Color(0xFF5C3D2E)),
      'playground': (Icons.school, const Color(0xFF5C3D2E)),
      'beauty': (Icons.content_cut, const Color(0xFF5C3D2E)),
      'cafe': (Icons.coffee, const Color(0xFF5C3D2E)),
      'hotel': (Icons.hotel, const Color(0xFF5C3D2E)),
    };
    for (final entry in configs.entries) {
      bookmarkIcons[entry.key] = await NOverlayImage.fromWidget(
        widget: _buildMarkerIconWidget(entry.value.$1, entry.value.$2, isHighlighted: true),
        size: const Size(40, 40),
        context: context,
      );
    }
    debugPrint("✅ Bookmark marker icons built");
  }

  Widget _buildMarkerIconWidget(dynamic iconData, Color borderColor, {bool isHighlighted = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: isHighlighted ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? AppColors.softSalmon : AppColors.mocha).withOpacity(isHighlighted ? 0.3 : 0.12),
            blurRadius: isHighlighted ? 6 : 4,
            offset: Offset(0, isHighlighted ? 3 : 2),
          ),
        ],
      ),
      child: Center(
        child: iconData is IconData
            ? Icon(iconData, size: 18, color: borderColor)
            : Text(iconData.toString(), style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Future<void> loadNearbyPlaces() async {
    try {
      double? lat, lon;
      double? zoom;
      double? minLat, minLon, maxLat, maxLon;

      if (mapController != null) {
        final camera = await mapController!.getCameraPosition();
        lat = camera.target.latitude;
        lon = camera.target.longitude;
        zoom = camera.zoom;
        
        final bounds = await mapController!.getContentBounds();
        minLat = bounds.southWest.latitude;
        minLon = bounds.southWest.longitude;
        maxLat = bounds.northEast.latitude;
        maxLon = bounds.northEast.longitude;
      }

      final places = await repository.searchNearbyPetPlaces(
        lat: lat, lon: lon,
        zoomLevel: zoom,
        minLat: minLat, minLon: minLon,
        maxLat: maxLat, maxLon: maxLon,
      );
      nearbyPlaces.value = places;
      showCategoryMarkers();
      debugPrint("📍 Loaded ${places.length} nearby pet places");
    } catch (e) {
      debugPrint("❌ Failed to load nearby places: $e");
    }
  }

  String? _iconKeyForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('병원') || cat.contains('의료')) return 'hospital';
    if (cat.contains('용품') || cat.contains('마트') || cat.contains('샵')) return 'store';
    if (cat.contains('놀이터') || cat.contains('공원') || cat.contains('유치원')) return 'playground';
    if (cat.contains('미용') || cat.contains('헤어')) return 'beauty';
    if (cat.contains('카페') || cat.contains('커피')) return 'cafe';
    if (cat.contains('호텔') || cat.contains('숙소')) return 'hotel';
    return null;
  }

  void showCategoryMarkers() {
    if (mapController == null || nearbyPlaces.isEmpty || categoryIcons.isEmpty) return;

    for (int i = 0; i < nearbyPlaces.length; i++) {
      final place = nearbyPlaces[i];
      final iconKey = _iconKeyForCategory(place.category);
      
      final isSelected = selectedPlace.value?.id == place.id;
      final icon = isSelected
          ? (softSalmonCategoryIcons[iconKey] ?? softSalmonCategoryIcons['default'])
          : (categoryIcons[iconKey] ?? categoryIcons['default']);

      final marker = NMarker(
        id: 'pet_place_$i',
        position: NLatLng(place.latitude, place.longitude),
        icon: icon,
      );
      marker.setOnTapListener((_) => onPlaceTapped(place));
      mapController?.addOverlay(marker);
    }
  }

  Future<void> _fitBoundsToResults() async {
    if (nearbyPlaces.isEmpty || mapController == null) return;

    try {
      // Compute actual bounds of all results
      double sLat = double.infinity, sLon = double.infinity;
      double nLat = -double.infinity, nLon = -double.infinity;

      for (var place in nearbyPlaces) {
        if (place.latitude < sLat) sLat = place.latitude;
        if (place.latitude > nLat) nLat = place.latitude;
        if (place.longitude < sLon) sLon = place.longitude;
        if (place.longitude > nLon) nLon = place.longitude;
      }

      // If all results at same point, zoom in close
      if ((nLat - sLat).abs() < 0.001 && (nLon - sLon).abs() < 0.001) {
        final center = NLatLng(sLat, sLon);
        mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: center, zoom: 15),
        );
        debugPrint("🔭 Single-point zoom to (${center.latitude}, ${center.longitude})");
        return;
      }

      final bounds = NLatLngBounds(
        southWest: NLatLng(sLat, sLon),
        northEast: NLatLng(nLat, nLon),
      );

      final update = NCameraUpdate.fitBounds(
        bounds,
        padding: const EdgeInsets.all(70),
      );

      mapController?.updateCamera(update);
      debugPrint("🔭 Camera moved to result bounds ($sLat~$nLat, $sLon~$nLon)");

    } catch (e) {
      debugPrint("⚠️ Auto-zoom failed: $e");
    }
  }

  // ─── Search ─────────────────────────────────────────────

  // ─── Search ─────────────────────────────────────────────
  
  void onSearchTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      showDropdown.value = false;
      searchSuggestions.clear();
      return;
    }
    showDropdown.value = true;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      // Autocomplete only: Fetch suggestions, do NOT update map
      _fetchSuggestions(text.trim());
    });
  }

  /// Called when user presses Enter/search on keyboard.
  void onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    searchFocusNode.unfocus();
    showDropdown.value = false;
    showBottomSheet.value = true;
    hideCategories.value = true;
    
    // Set active search context
    currentSearchQuery.value = query.trim();
    selectedCategory.value = '전체'; // Clear category mode if explicit search
    
    // Final Search: Update Map & Bottom Sheet
    _performSearch(query.trim(), isSubmit: true);
  }

  /// Fetch autocomplete suggestions — raw query only, no region prefix.
  /// Uses sort:sim (accuracy) for best relevance.
  Future<void> _fetchSuggestions(String query) async {
    try {
      double? lat, lon;
      if (mapController != null) {
        final camera = await mapController!.getCameraPosition();
        lat = camera.target.latitude;
        lon = camera.target.longitude;
      }

      final results = await repository.searchSuggestions(
        query,
        maxResults: 5,
        lat: lat,
        lon: lon,
      );

      // Deduplicate by title+address
      final Map<String, PlaceEntity> unique = {};
      for (final place in results) {
        final key = '${place.title}_${place.address}';
        unique.putIfAbsent(key, () => place);
      }

      searchSuggestions.value = unique.values.toList();
      debugPrint('🔍 Suggestions: ${searchSuggestions.length} unique results');
    } catch (e) {
      debugPrint("Autocomplete error: $e");
      searchSuggestions.clear();
    }
  }

  Future<void> _performSearch(String query, {required bool isSubmit, bool isMapAreaSearch = false, bool isCategoryTap = false}) async {
    isSearching.value = true;
    
    searchResults.clear();
    nearbyPlaces.clear();
    mapController?.clearOverlays();
    
    // ─── Search Mode ─────────────────────────────────────
    // GLOBAL: User typed a keyword and pressed Enter (e.g. "롯데월드")
    //   → Raw query, NO region prefix, strictBounds=false, camera moves
    // LOCAL:  Category button tap OR "현 지도에서 검색"
    //   → 3×3 grid region sampling, strictBounds=true, no camera move
    final bool isGlobalSearch = isSubmit && !isMapAreaSearch && !isCategoryTap;
    final bool isLocalSearch = isMapAreaSearch || isCategoryTap;

    try {
      double? lat, lon;
      double? zoom;
      double? minLat, minLon, maxLat, maxLon;

      if (mapController != null) {
        final camera = await mapController!.getCameraPosition();
        lat = camera.target.latitude;
        lon = camera.target.longitude;
        zoom = camera.zoom;
        
        final bounds = await mapController!.getContentBounds();
        minLat = bounds.southWest.latitude;
        minLon = bounds.southWest.longitude;
        maxLat = bounds.northEast.latitude;
        maxLon = bounds.northEast.longitude;
      }

      List<PlaceEntity> finalResults = [];

      if (isGlobalSearch) {
        // ══════════════════════════════════════════════════
        // GLOBAL SEARCH — Raw query, no region, no bounds
        // ══════════════════════════════════════════════════
        debugPrint("🌐 Global Search: \"$query\" (strictBounds: false)");

        final results = await repository.searchPlaces(
          query,
          lat: lat,
          lon: lon,
          strictBounds: false,  // NEVER filter by bounds for keyword search
        );
        finalResults = results;
        
      } else {
        // ══════════════════════════════════════════════════
        // LOCAL SEARCH — Grid sampling + strict bounds
        // ══════════════════════════════════════════════════
        final Set<String> targetRegions = {};

        if (minLat != null && maxLat != null && minLon != null && maxLon != null) {
          final latRange = maxLat - minLat;
          final lonRange = maxLon - minLon;
          final points = <(double, double)>[];
          for (final latFrac in [0.25, 0.50, 0.75]) {
            for (final lonFrac in [0.25, 0.50, 0.75]) {
              points.add((minLat + latRange * latFrac, minLon + lonRange * lonFrac));
            }
          }

          debugPrint("📍 Local Search: 3×3 Grid (${points.length} points)");

          final regionFutures = points.map((p) => repository.getRegionName(p.$1, p.$2));
          final regions = await Future.wait(regionFutures);
          for (var r in regions) {
            if (r != null && r.isNotEmpty) targetRegions.add(r);
          }
          debugPrint("📍 Regions found: $targetRegions");
        }

        // Fallback to center region
        if (targetRegions.isEmpty && lat != null && lon != null) {
          final r = await repository.getRegionName(lat, lon);
          if (r != null) targetRegions.add(r);
        }

        // Build queries: "동이름 keyword"
        List<String> searchQueries;
        if (targetRegions.isNotEmpty) {
          searchQueries = targetRegions.map((r) => "$r $query").toList();
        } else {
          searchQueries = [query];
        }

        debugPrint("🚀 Local Queries: $searchQueries (strictBounds: true)");

        final searchFutures = searchQueries.map((q) => repository.searchPlaces(
          q,
          lat: lat,
          lon: lon,
          zoomLevel: zoom,
          minLat: minLat, minLon: minLon,
          maxLat: maxLat, maxLon: maxLon,
          strictBounds: true,
        ));

        final allResultsList = await Future.wait(searchFutures);

        // Merge & deduplicate
        final Map<String, PlaceEntity> merged = {};
        for (final list in allResultsList) {
          for (final place in list) {
            final key = '${place.title}_${place.address}';
            merged.putIfAbsent(key, () => place);
          }
        }
        finalResults = merged.values.toList();
      }

      // Sort by distance
      if (lat != null && lon != null) {
        finalResults.sort((a, b) => a.distance.compareTo(b.distance));
      }

      debugPrint("✅ Search Result: ${finalResults.length} items (Global: $isGlobalSearch)");

      // Update UI
      nearbyPlaces.value = finalResults;
      searchResults.value = finalResults;
      nearbyPlaces.refresh();
      searchResults.refresh();
      
      if (finalResults.isEmpty && !isLocalSearch) {
        Get.closeAllSnackbars();
        Get.snackbar(
          "알림",
          "검색 결과가 없습니다.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.deepBrown.withOpacity(0.7),
          colorText: AppColors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        );
      }

      isSearching.value = false;

      if (isSubmit) {
        repository.addSearchHistory(query);
        _loadHistory();
      }

      // Camera: move for global, stay for local
      if (isGlobalSearch && finalResults.isNotEmpty) {
        showCategoryMarkers();
        await _fitBoundsToResults();
      } else {
        showCategoryMarkers();
      }
      
      if (searchResults.isNotEmpty && !showBottomSheet.value) {
        showBottomSheet.value = true;
      }

    } catch (e) {
      debugPrint("❌ Search failed: $e");
      searchResults.clear();
    } finally {
      isSearching.value = false;
      nearbyPlaces.refresh();
      searchResults.refresh();
      update(); 
      if (searchResults.isNotEmpty && showBottomSheet.value) {
        try { 
          if (sheetController.isAttached) {
            sheetController.animateTo(0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
        } catch(e) {}
      }
    }
  }

  // ─── Category ───────────────────────────────────────────

  Future<void> onCategoryTapped(String category) async {
    // If tapping the same category, deselect it (toggle off)
    if (selectedCategory.value == category) {
      selectedCategory.value = '';
      onClearSearch();
      return;
    }

    selectedCategory.value = category;
    final keyword = _categoryKeywords[category];

    if (keyword == null) {
      currentSearchQuery.value = ''; 
      onClearSearch();
      return;
    }
    
    // Explicitly show bottom sheet for results
    showBottomSheet.value = true;
    hideCategories.value = true;
    searchController.text = keyword; 
    currentSearchQuery.value = ''; // Category mode

    // Use unified search
    await _performSearch(keyword, isSubmit: true, isCategoryTap: true); 
  }

  Future<void> _reloadAllCategoryMarkers() async {
    showBottomSheet.value = true;
    hideCategories.value = true;
    searchResults.clear();
    searchController.clear();
    mapController?.clearOverlays();
    await loadNearbyPlaces();
    searchResults.value = nearbyPlaces.value;

    if (searchResults.isNotEmpty && showBottomSheet.value) {
      try { 
        if (sheetController.isAttached) {
          sheetController.animateTo(0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      } catch(e) {}
    }
  }

  // ─── Place Tapped ───────────────────────────────────────

  void onPlaceTapped(PlaceEntity place) {
    repository.addSearchHistory(place.title);
    _loadHistory();

    selectedPlace.value = place;
    showBottomSheet.value = false;
    hideCategories.value = true;

    final target = NLatLng(place.latitude, place.longitude);
    mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: target, zoom: 16),
    );
    mapController?.clearOverlays();

    // ✅ 선택된 장소 마커 직접 추가
    if (categoryIcons.isNotEmpty) {
      final iconKey = _iconKeyForCategory(place.category);
      final icon = softSalmonCategoryIcons[iconKey] 
          ?? softSalmonCategoryIcons['default']!;
      final marker = NMarker(
        id: 'selected_place_${place.id}',
        position: NLatLng(place.latitude, place.longitude),
        icon: icon,
      );
      marker.setOnTapListener((_) => onPlaceTapped(place));
      mapController?.addOverlay(marker);
    }

    if (currentSearchQuery.value.isEmpty && selectedCategory.value.isEmpty) {
      _showBookmarkMarkers();
    }
    showCategoryMarkers();

    searchFocusNode.unfocus();
  }

  void onCloseDetailPanel() {
    selectedPlace.value = null;
    // ✅ 검색창에 텍스트가 있으면 카테고리 칩 숨김 유지
    if (searchController.text.isEmpty) {
      hideCategories.value = false;
    }
    mapController?.clearOverlays();
    _showBookmarkMarkers(); // 북마크 마커 복원
    showCategoryMarkers();
  }

  // ─── Search in Map Area ─────────────────────────────────

  Future<void> onSearchInMapArea() async {
    showSearchInMapButton.value = false;
    if (mapController == null) return;

    String finalQuery = '';
      
    // Determine base query from context
    if (currentSearchQuery.value.isNotEmpty) {
      finalQuery = currentSearchQuery.value;
    } else if (selectedCategory.value.isNotEmpty && selectedCategory.value != '전체') {
      final keyword = _categoryKeywords[selectedCategory.value];
      if (keyword != null) {
        finalQuery = keyword;
      }
    }

    if (finalQuery.isEmpty) {
        // Fallback if no context
        await loadNearbyPlaces();
        searchResults.value = nearbyPlaces.value;
        if (searchResults.isNotEmpty && !showBottomSheet.value) {
          showBottomSheet.value = true;
        }
        return;
    }

    // Use unified search
    await _performSearch(finalQuery, isSubmit: true, isMapAreaSearch: true);
  }

  // ─── History ────────────────────────────────────────────

  Future<void> _loadHistory() async {
    searchHistory.value = await repository.loadSearchHistory();
  }

  void removeHistory(String query) {
    repository.removeSearchHistory(query);
    _loadHistory();
  }

  void clearAllHistory() {
    repository.clearSearchHistory();
    searchHistory.clear();
  }

  // ─── Reset ──────────────────────────────────────────────

  /// Called when user taps the X (clear) button in the search bar.
  /// Clears all search-related state and restores map to default.
  void onClearSearch() {
    if (isClosed) return;
    _debounce?.cancel();
    try {
      searchController.clear();
      if (searchFocusNode.hasFocus) searchFocusNode.unfocus();
    } catch (e) {
      debugPrint("⚠️ searchController/focusNode already disposed");
    }
    
    // Clear ALL search-related data first
    searchResults.clear();
    searchSuggestions.clear();
    nearbyPlaces.clear();
    
    // Reset ALL UI state flags in one batch
    isSearching.value = false;
    isSearchFocused.value = false;
    showBottomSheet.value = false;
    showDropdown.value = false;
    hideCategories.value = false;
    showSearchInMapButton.value = false;
    currentSearchQuery.value = '';
    selectedCategory.value = '';
    selectedPlace.value = null;
    
    // Clear overlays and results without reloading default markers
    mapController?.clearOverlays();
    // loadNearbyPlaces(); // REMOVED: Do not restore default markers
    
    // Restore bookmark markers after clearing search
    _showBookmarkMarkers();
  }

  void reset() {
    if (isClosed) return;
    try {
      searchController.clear();
      if (searchFocusNode.hasFocus) searchFocusNode.unfocus();
    } catch (e) {
      debugPrint("⚠️ searchController/focusNode already disposed in reset");
    }
    selectedPlace.value = null;
    searchResults.clear();
    isSearching.value = false;
    isSearchFocused.value = false;
    showBottomSheet.value = false;
    showDropdown.value = false;
    hideCategories.value = false;
    selectedCategory.value = '';
    showSearchInMapButton.value = false;
    currentSearchQuery.value = ''; // Clear context
    mapController?.clearOverlays();
    showCategoryMarkers();
    searchSuggestions.clear();
    
    // 홈 탭 복귀 시 북마크 마커 복원
    _showBookmarkMarkers();
  }

  void showBookmarkedPlaces() {
    final context = Get.context;
    if (context == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFFDFCFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const BookmarkedPlacesPage(isBottomSheet: true),
      ),
    );
  }
}
