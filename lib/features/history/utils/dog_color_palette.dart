import 'package:flutter/material.dart';
import '../walk_model.dart';

const List<Color> _dogColorPalette = [
  Color(0xFFE53935), // Red
  Color(0xFF1E88E5), // Blue
  Color(0xFF43A047), // Green
  Color(0xFFFF9800), // Orange
  Color(0xFF8E24AA), // Purple
  Color(0xFF00897B), // Teal
  Color(0xFFD81B60), // Pink
  Color(0xFF6D4C41), // Brown
];

Map<String, Color> buildDogColorMap(List<Walk> allWalks) {
  final names = <String>{};
  for (final walk in allWalks) {
    names.addAll(walk.dogNameList);
  }
  final sorted = names.toList()..sort();
  final map = <String, Color>{};
  for (var i = 0; i < sorted.length; i++) {
    map[sorted[i]] = _dogColorPalette[i % _dogColorPalette.length];
  }
  return map;
}
