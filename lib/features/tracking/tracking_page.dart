
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'summary_page.dart';
import '../../utils/mock_location_service.dart';

import 'package:flutter_compass/flutter_compass.dart';

class TrackingPage extends StatefulWidget {
  final List<String> dogNames;
  const TrackingPage({super.key, this.dogNames = const []});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> with WidgetsBindingObserver {
  // State Variables
  NaverMapController? _mapController;
  final List<NLatLng> _pathPoints = [];
  Timer? _timer;
  int _durationSeconds = 0;
  double _distanceMeters = 0.0;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  
  double _currentHeading = 0.0; // Device Compass (for Marker)
  double _currentBearing = 0.0; // GPS Movement (for Camera)
  
  // Custom Icons
  NOverlayImage? _arrowIcon;

  // Reporting State
  final bool _isReportingMode = false;
  bool _isSimulationMode = false; // Simulation Toggle
  
  // UI Constants
  // 1. 바깥 글로우 선 (연한 색, 두껍게)
  final NPathOverlay _glowOverlay = NPathOverlay(
    id: "path_glow",
    coords: [],
    width: 14,
    color: const Color(0x403A200B), // deepBrown 25% 투명도
    outlineWidth: 0,
  );

  // 2. 안쪽 메인 선 (진한 색, 얇게)
  final NPathOverlay _mainOverlay = NPathOverlay(
    id: "path_main",
    coords: [],
    width: 8,
    color: const Color(0xB33A200B), // deepBrown 70% 투명도
    outlineColor: AppColors.white,
    outlineWidth: 2,
  );

  bool _isInitialCamMoved = false;
  bool _isTracking = true; // Smart tracking mode

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTracking();
    _startCompass();
    _moveToCurrentLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reserved for future lifecycle handling
  }

  void _moveToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      
      setState(() => _isTracking = true);
      
      _moveCameraToPosition(NLatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint("Initial loc failed: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }



  void _startCompass() {
    _compassStream = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() {
          _currentHeading = event.heading!;
        });
        _updateMarkerHeading();
      }
    });
  }
  
  void _updateMarkerHeading() async {
    if (_mapController != null && _arrowIcon != null) {
        final overlay = _mapController!.getLocationOverlay();
        overlay.setBearing(_currentHeading); 
    }
  }

  Future<void> _initLocationOverlay() async {
    if (_mapController == null) return;
    
    _arrowIcon ??= await NOverlayImage.fromWidget(
      widget: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white,
          boxShadow: [BoxShadow(color: AppColors.mocha.withOpacity(0.12), blurRadius: 4)],
        ),
        padding: const EdgeInsets.all(4),
        child: const Icon(Icons.navigation_rounded, color: AppColors.deepBrown, size: 30),
      ),
      size: const Size(40, 40),
      context: context,
    );

    final overlay = _mapController!.getLocationOverlay();
    overlay.setIcon(_arrowIcon!);
    overlay.setIsVisible(true);
    overlay.setAnchor(const NPoint(0.5, 0.5));
    
    if (_pathPoints.isNotEmpty) {
      _moveCameraToPosition(_pathPoints.last);
    } 
  }

  void _startTracking() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _durationSeconds++;
        });
    });

    _positionStream?.cancel();

    if (_isSimulationMode) {
      // Get current location to start simulation from
      Position startPos;
      try {
        startPos = await Geolocator.getCurrentPosition();
      } catch (e) {
        // Fallback if no location
        startPos = Position(
          latitude: 37.5665, longitude: 126.9780, 
          timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0, isMocked: true
        );
      }
      
      _positionStream = MockLocationService.getMockPositionStream(
        startLat: startPos.latitude, 
        startLng: startPos.longitude
      ).listen((Position position) {
        _updateLocation(position);
      });
      
    } else {
      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high, 
        distanceFilter: 5, 
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        _updateLocation(position);
      });
    }
  }

  void _updateLocation(Position position) async {

    setState(() {
      final newPoint = NLatLng(position.latitude, position.longitude);
      
      if (_pathPoints.isNotEmpty) {
        final lastPoint = _pathPoints.last;
        _distanceMeters += Geolocator.distanceBetween(
          lastPoint.latitude, lastPoint.longitude,
          newPoint.latitude, newPoint.longitude
        );
      }

      _pathPoints.add(newPoint);
      
      if (_pathPoints.length >= 2) {
         _glowOverlay.setCoords(_pathPoints);
         _mainOverlay.setCoords(_pathPoints);
         _mapController?.addOverlayAll({_glowOverlay, _mainOverlay});
      }
      
      final overlay = _mapController?.getLocationOverlay();
      overlay?.setPosition(newPoint);

      // Separate camera movement from state updates
      if (!_isReportingMode && _isTracking) {
        _animateCameraToNewPoint(newPoint, position.heading, position.speed);
      }
    });
  }

  void _animateCameraToNewPoint(NLatLng point, double heading, double speed) {
    if (_mapController == null) return;

    double bearing = _currentBearing;
    if (speed > 0.5) {
      bearing = heading;
      _currentBearing = bearing;
    }

    final cameraUpdate = NCameraUpdate.withParams(
      target: point,
      zoom: 17,
      bearing: bearing,
      tilt: 0,
    );
    cameraUpdate.setAnimation(
      animation: NCameraAnimation.linear,
      duration: const Duration(milliseconds: 800),
    );
    _mapController?.updateCamera(cameraUpdate);
    _isInitialCamMoved = true;
  }
  

  
  void _moveCameraToPosition(NLatLng point) {
    if (_mapController == null) return;
    
    // Reset to 2D North-Up view
    final update = NCameraUpdate.withParams(
      target: point,
      zoom: 17,
      bearing: 0,
      tilt: 0,
    );
    update.setAnimation(animation: NCameraAnimation.easing, duration: const Duration(milliseconds: 1000));
    _mapController!.updateCamera(update);
    _isInitialCamMoved = true;
  }

  void _finishWalk() {
    _timer?.cancel();
    _positionStream?.cancel();

    if (_distanceMeters <= 0 || _durationSeconds <= 0) {
      _showZeroDistanceDialog();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          durationSeconds: _durationSeconds,
          distanceMeters: _distanceMeters,
          pathPoints: _pathPoints,
          dogNames: widget.dogNames,
        ),
      ),
    );
  }

  void _showZeroDistanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("산책 기록 없음"),
        content: const Text("움직인 거리가 0m라 히스토리에 저장되지 않습니다.\n산책을 끝낼까요?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startTracking(); // Restart
            },
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit
            },
            child: const Text("확인", style: TextStyle(color: AppColors.deepBrown)),
          ),
        ],
      ),
    );
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Map
          NaverMap(
            options: const NaverMapViewOptions(
              customStyleId: 'e0aa762a-75d3-4e45-a38e-dd8385fefb73',
              locationButtonEnable: false, 
              consumeSymbolTapEvents: false,
              logoClickEnable: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _initLocationOverlay();
              _moveToCurrentLocation(); 
            },
            onCameraChange: (reason, animated) {
              if (reason == NCameraUpdateReason.gesture) {
                if (_isTracking) {
                  setState(() {
                    _isTracking = false;
                  });
                }
              }
            },
            onMapTapped: (point, latLng) {},
          ),

          // 2. My Location Button
          Positioned(
            bottom: bottomPadding + 120, 
            right: 20,
            child: FloatingActionButton.small(
              heroTag: "my_loc_tracking",
              backgroundColor: AppColors.white,
              foregroundColor: AppColors.deepBrown,
              onPressed: _moveToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          
          // Simulation Toggle (Test Feature)
          Positioned(
            bottom: bottomPadding + 170, 
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "sim_toggle",
                  backgroundColor: _isSimulationMode ? AppColors.latte : AppColors.white,
                  foregroundColor: _isSimulationMode ? AppColors.white : AppColors.deepBrown,
                  onPressed: () {
                    setState(() {
                      _isSimulationMode = !_isSimulationMode;
                    });
                     // Restart tracking with new mode
                     _startTracking();
                     
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(_isSimulationMode ? "Simulation ON (Square Walk)" : "Simulation OFF (Real GPS)"))
                     );
                  },
                  child: const Icon(Icons.directions_walk),
                ),
                const SizedBox(height: 4),
                const Text("TEST", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.white, shadows: [Shadow(color: AppColors.deepBrown, blurRadius: 2)])),
              ],
            ),
          ),
          
          // 3. Bottom Controls
          Positioned(
            bottom: bottomPadding + 20, 
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(50), 
                boxShadow: [
                  BoxShadow(color: AppColors.mocha.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildInfoItem("시간", _formatDuration(_durationSeconds), AppColors.deepBrown),
                      const SizedBox(width: 24),
                      Container(width: 1, height: 20, color: AppColors.sand),
                      const SizedBox(width: 24),
                      _buildInfoItem("거리", _formatDistance(_distanceMeters), AppColors.deepBrown),
                    ],
                  ),
                  
                  InkWell(
                    onTap: () {
                         showDialog(
                          context: context, 
                          builder: (context) => AlertDialog(
                            title: const Text("산책 종료"),
                            content: const Text("산책을 종료하시겠습니까?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소")),
                              TextButton(onPressed: () {
                                Navigator.pop(context);
                                _finishWalk();
                              }, child: const Text("종료", style: TextStyle(color: AppColors.deepBrown))),
                            ],
                          )
                        );
                    },
                    child: Container(
                      width: 50, height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.deepBrown,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.stop_rounded, color: AppColors.white, size: 30),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label, style: const TextStyle(fontSize: 10, color: AppColors.taupe, fontWeight: FontWeight.bold)),
           const SizedBox(height: 2),
           Text(value, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
        ],
      );
  }
}

