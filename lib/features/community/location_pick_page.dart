import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import '../../core/app_colors.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../data/providers/naver_api_provider.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickPage extends StatefulWidget {
  const LocationPickPage({super.key});

  @override
  State<LocationPickPage> createState() => _LocationPickPageState();
}

class _LocationPickPageState extends State<LocationPickPage> {
  late final SearchRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  final List<PlaceEntity> _searchResults = [];
  
  NaverMapController? _mapController;
  PlaceEntity? _selectedPlace;
  bool _isSearching = false;
  Timer? _debounce;
  NLatLng? _currentCenter;
  
  NCameraUpdateReason? _lastCameraChangeReason;
  bool _isReverseGeocoding = false;

  NCameraPosition? _initialCameraPosition;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    // Simple instantiation for now, assuming provider is available
    _repository = SearchRepositoryImpl(apiProvider: NaverApiProvider());
    
    _searchController.addListener(_onSearchChanged);
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission denied forever');
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _initialCameraPosition = NCameraPosition(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 15,
          );
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback to Seoul Station
          _initialCameraPosition = const NCameraPosition(
            target: NLatLng(37.5546, 126.9706),
            zoom: 15,
          );
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_isReverseGeocoding) return; // Prevent auto-search when we're updating text via reverse geocoding
    
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final query = _searchController.text;
    
    // If the query matches the selected place, don't search again
    if (_selectedPlace != null && query == _selectedPlace!.title) {
      return;
    }

    if (query.isEmpty) {
      if (_searchResults.isNotEmpty) {
        setState(() => _searchResults.clear());
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.trim().isNotEmpty) {
        _onSearch(query);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() => _isSearching = true);
    try {
      final camera = await _mapController?.getCameraPosition();
      final results = await _repository.searchPlaces(
        query,
        lat: camera?.target.latitude,
        lon: camera?.target.longitude,
      );
      
      setState(() {
        _searchResults.clear();
        _searchResults.addAll(results);
        _isSearching = false;
      });
      
      if (results.isEmpty && query.length > 2) {
        // Only show snackbar for explicit searches or long queries that return nothing
      }
    } catch (e) {
      setState(() => _isSearching = false);
      Get.snackbar('오류', '검색 중 문제가 발생했습니다.');
    }
  }

  void _onCameraChange(NCameraUpdateReason reason, bool animated) async {
    _lastCameraChangeReason = reason;
  }

  void _onCameraIdle() async {
    if (_mapController == null) return;
    
    final cameraPosition = await _mapController!.getCameraPosition();
    final center = cameraPosition.target;

    setState(() {
      _currentCenter = center;
    });

    // Only reverse geocode if the map was moved by user gesture
    if (_lastCameraChangeReason == NCameraUpdateReason.gesture) {
       _performReverseGeocoding(center.latitude, center.longitude);
    }
  }

  Future<void> _performReverseGeocoding(double lat, double lon) async {
    setState(() {
      _isReverseGeocoding = true;
      _searchController.text = '위치 확인 중...';
      _searchResults.clear();
      _selectedPlace = null;
    });

    try {
      final regionName = await _repository.getRegionName(lat, lon);
      
      if (!mounted) return;
      
      final displayName = regionName ?? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

      setState(() {
        _searchController.text = displayName;
        _selectedPlace = PlaceEntity(
           title: displayName,
           address: displayName,
           roadAddress: displayName,
           category: 'location',
           latitude: lat,
           longitude: lon,
           telephone: '',
        );
      });
    } catch (e) {
      if (!mounted) return;
      final fallbackName = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
      setState(() {
        _searchController.text = fallbackName;
        _selectedPlace = PlaceEntity(
           title: fallbackName,
           address: fallbackName,
           roadAddress: fallbackName,
           category: 'location',
           latitude: lat,
           longitude: lon,
           telephone: '',
        );
      });
    } finally {
      if (mounted) {
        // Add a slight delay before re-enabling normal search behavior
        // to ensure the text field update doesn't trigger a new search
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
           _isReverseGeocoding = false;
        });
      }
    }
  }

  void _selectPlace(PlaceEntity place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedPlace = place;
      _searchResults.clear();
      _searchController.text = place.title;
      _currentCenter = NLatLng(place.latitude, place.longitude);
    });

    final target = NLatLng(place.latitude, place.longitude);
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: target, zoom: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택', style: TextStyle(color: AppColors.deepBrown, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.deepBrown),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        children: [
          // Naver Map
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator(color: AppColors.deepBrown))
              : NaverMap(
                  options: NaverMapViewOptions(
                    customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
                    initialCameraPosition: _initialCameraPosition ??
                        const NCameraPosition(
                          target: NLatLng(37.5547, 126.9707),
                          zoom: 15,
                        ),
                    locationButtonEnable: true,
                    logoClickEnable: false,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;
                    final pos = await controller.getCameraPosition();
                    if (mounted) setState(() => _currentCenter = pos.target);
                  },
                  onCameraChange: _onCameraChange,
                  onCameraIdle: _onCameraIdle,
                ),
          
          // Fixed Center Pin
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32), // Half height of the icon + some offset
              child: Icon(
                Icons.location_on, 
                size: 48, 
                color: AppColors.deepBrown,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
            ),
          ),
          
          // Search Bar Overlay
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '공원, 카페 등 장소 검색',
                      prefixIcon: const Icon(Icons.search, color: AppColors.taupe),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.taupe),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults.clear());
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: _onSearch,
                  ),
                ),
                
                // Results List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final p = _searchResults[index];
                        return ListTile(
                          title: Text(p.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text(p.roadAddress.isNotEmpty ? p.roadAddress : p.address, style: const TextStyle(fontSize: 12)),
                          onTap: () => _selectPlace(p),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Selection Button
          if (_currentCenter != null)
            Positioned(
              bottom: 24, left: 24, right: 24,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(result: {
                      'title': _selectedPlace?.title ?? '이름 없는 장소',
                      'lat': _currentCenter!.latitude,
                      'lng': _currentCenter!.longitude,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepBrown,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: const Text('이 위치로 선택하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
