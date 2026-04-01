import 'dart:convert';

/// Pure domain entity representing a place.
/// No framework dependencies — only plain Dart.
class PlaceEntity {
  final String id;
  final String title;
  final String address;
  final String roadAddress;
  final String category;
  final String telephone;
  final double latitude;
  final double longitude;

  /// Distance from the user's current location in meters.
  /// Computed at search time; defaults to 0.
  double distance;

  PlaceEntity({
    String? id,
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.category,
    required this.telephone,
    required this.latitude,
    required this.longitude,
    this.distance = 0,
  }) : id = id ?? _generateId(title, address, roadAddress);

  static String _generateId(String title, String address, String roadAddress) {
    final raw = '${title}_${address.isNotEmpty ? address : roadAddress}';
    return raw.replaceAll(RegExp(r'[^\w]'), '_');
  }

  /// Human-readable distance string (e.g. "1.2km", "340m").
  String get distanceLabel {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
    return '${distance.toInt()}m';
  }
}
