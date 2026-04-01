import 'dart:async';
import 'package:geolocator/geolocator.dart';

class MockLocationService {
  // Simulate a walk around Seoul City Hall
  // Starting point
  static const double startLat = 37.5665; 
  static const double startLng = 126.9780;

  static Stream<Position> getMockPositionStream({
    required double startLat, 
    required double startLng
  }) async* {
    double currentLat = startLat;
    double currentLng = startLng;
    
    // ~11 meters per 0.0001 degrees
    const double step = 0.0001; 
    
    // Infinite loop or until cancelled
    int stepCount = 0;
    
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      stepCount++;
      
      // Move in a square pattern every 10 steps (approx 100m side)
      // 0-9: East
      // 10-19: North
      // 20-29: West
      // 30-39: South
      
      final cycle = stepCount % 40;
      
      if (cycle < 10) {
        currentLng += step; // East
      } else if (cycle < 20) {
        currentLat += step; // North
      } else if (cycle < 30) {
        currentLng -= step; // West
      } else {
        currentLat -= step; // South
      }
      
      yield Position(
        latitude: currentLat,
        longitude: currentLng,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        heading: 0.0, // Could calculate real heading if needed
        speed: 1.5, // ~5.4 km/h walking speed
        speedAccuracy: 0.5, 
        altitudeAccuracy: 1.0, 
        headingAccuracy: 1.0,
        isMocked: true,
      );
    }
  }
}
