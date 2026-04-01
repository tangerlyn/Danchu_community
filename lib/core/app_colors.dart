import 'package:flutter/material.dart';

/// Pawprint brand color palette — 7 colors only.
/// All UI elements must use these colors exclusively.
class AppColors {
  AppColors._(); // Prevent instantiation

  // ─── Brand Palette (Dark → Light) ─────────────────────
  static const Color deepBrown = Color(0xFF3A200B);
  static const Color mocha     = Color(0xFF3C2A1A);
  static const Color latte     = Color(0xFF59483A);
  static const Color taupe     = Color(0xFF8B7C70);
  static const Color sand      = Color(0xFFD0BCAB);
  static const Color lightSand = Color(0xFFE6D5C7);
  static const Color white     = Color(0xFFFFFFFF);
  static const Color softSalmon = Color(0xFFFFAB91);

  // ─── Semantic Aliases ─────────────────────────────────
  static const Color primaryButton    = deepBrown;
  static const Color primaryText      = deepBrown;
  static const Color secondaryText    = mocha;
  static const Color bodyText         = latte;
  static const Color hintText         = taupe;
  static const Color cardBackground   = white;
  static const Color scaffoldBg       = white;
  static const Color dividerColor     = sand;
  static const Color iconColor        = latte;
  static const Color iconOnDark       = white;
  static const Color textOnDark       = white;

  // ─── Shadows ──────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: mocha.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: latte.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
