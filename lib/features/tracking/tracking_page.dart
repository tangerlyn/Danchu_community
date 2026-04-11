
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:pawprint_app/core/app_colors.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'summary_page.dart';

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
    _initWithPermission();
  }

  Future<void> _initWithPermission() async {
    final granted = await _requestLocationPermission();
    if (!mounted) return;

    if (!granted) {
      // 권한 없으면 산책 페이지 닫고 홈으로 돌아가기
      Navigator.of(context).pop();
      return;
    }

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
      
      if (_mapController == null) return;
      
      final update = NCameraUpdate.withParams(
        target: NLatLng(pos.latitude, pos.longitude),
        zoom: 17,
        bearing: _currentHeading, // 나침반 방향으로 정렬해서 화살표가 위를 향하게
        tilt: 0,
      );
      update.setAnimation(
        animation: NCameraAnimation.easing,
        duration: const Duration(milliseconds: 1000),
      );
      _mapController!.updateCamera(update);
      _isInitialCamMoved = true;
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

  Future<bool> _requestLocationPermission() async {
    // 1. 위치 서비스 켜져 있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("위치 서비스를 켜주세요")),
        );
      }
      return false;
    }

    // 2. 권한 상태 확인
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("위치 권한이 필요합니다")),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("위치 권한 필요"),
            content: const Text("백그라운드에서도 산책 경로를 기록하려면 '항상 허용' 권한이 필요해요. 설정에서 위치 권한을 변경해주세요."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("취소"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text("설정 열기"),
              ),
            ],
          ),
        );
      }
      return false;
    }

    // 3. "사용 중에만" 권한이면 "항상" 권한으로 업그레이드 안내
    if (permission == LocationPermission.whileInUse) {
      if (mounted) {
        final shouldUpgrade = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // 바깥 탭으로 닫지 못하게
          builder: (ctx) => AlertDialog(
            title: const Text("백그라운드 추적 권한"),
            content: const Text("앱이 백그라운드에 있을 때도 산책 경로를 끊김 없이 기록하려면 '항상 허용' 권한이 필요해요.\n\n설정 앱에서 위치 권한을 '항상'으로 변경해주세요."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("나중에"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("설정 열기"),
              ),
            ],
          ),
        );

        if (shouldUpgrade == true) {
          await Geolocator.openAppSettings();
          // 설정에서 돌아와도 다시 권한 확인이 필요하므로 false 반환 → 사용자가 다시 산책 시작
          return false;
        } else {
          // "나중에"를 선택하면 산책 불가
          return false;
        }
      }
      return false;
    }

    return permission == LocationPermission.always;
  }

  void _startTracking() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _durationSeconds++;
        });
    });

    _positionStream?.cancel();

    late LocationSettings locationSettings;

    if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "산책 경로를 기록하고 있어요 🐾",
          notificationTitle: "단추 산책 중",
          enableWakeLock: true,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      );
    }

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      _updateLocation(position);
    });
  }

  void _updateLocation(Position position) async {
    // GPS 정확도 필터: 40m보다 부정확한 점은 버림
    if (position.accuracy > 40) {
      debugPrint("🚫 GPS 정확도 낮음 (${position.accuracy.toStringAsFixed(1)}m), 무시");
      return;
    }

    setState(() {
      final newPoint = NLatLng(position.latitude, position.longitude);
      
      if (_pathPoints.isNotEmpty) {
        final lastPoint = _pathPoints.last;
        final dist = Geolocator.distanceBetween(
          lastPoint.latitude, lastPoint.longitude,
          newPoint.latitude, newPoint.longitude
        );
        // 3m 미만이거나 100m 초과면 GPS 튐으로 간주하고 무시
        if (dist < 3 || dist > 100) return;
        _distanceMeters += dist;
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

