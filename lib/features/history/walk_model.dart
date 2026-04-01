import 'dart:convert';

class Walk {
  final int? id;
  final DateTime startTime;
  final int durationSeconds;
  final double distanceMeters;
  final String? routePoints; // JSON-encoded [[lat,lng], ...]
  final String? dogNames;    // Comma-separated dog names, e.g. "초코,초쿠"

  Walk({
    this.id,
    required this.startTime,
    required this.durationSeconds,
    this.distanceMeters = 0.0,
    this.routePoints,
    this.dogNames,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'routePoints': routePoints,
      'dogNames': dogNames,
    };
  }

  factory Walk.fromMap(Map<String, dynamic> map) {
    return Walk(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      durationSeconds: map['durationSeconds'],
      distanceMeters: map['distanceMeters'],
      routePoints: map['routePoints'],
      dogNames: map['dogNames'] as String?,
    );
  }

  /// Get list of dog names from the comma-separated string
  List<String> get dogNameList {
    if (dogNames == null || dogNames!.isEmpty) return [];
    return dogNames!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Decode routePoints JSON into a list of [lat, lng] pairs
  List<List<double>> get decodedRoutePoints {
    if (routePoints == null || routePoints!.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(routePoints!);
      return decoded.map<List<double>>((point) {
        return [
          (point[0] as num).toDouble(),
          (point[1] as num).toDouble(),
        ];
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
