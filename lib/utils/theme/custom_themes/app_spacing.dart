// ─────────────────────────────────────────
// Theme: AppSpacing
// Description: Standardised spacing constants for consistent layouts.
// Contains: xs, sm, md, lg, xl spacing values
// ─────────────────────────────────────────

import 'package:flutter/material.dart';

class AppSpacing {
  // --- Padding & Margins ---
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // --- Screen Standard Margins ---
  static const double screenMargin = 16.0;
  static const double screenMarginLarge = 20.0;
  static const double sectionGap = 24.0;
  static const double elementGap = 12.0;

  // --- Border Radii ---
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusXXL = 32.0;

  // --- Common Insets ---
  static const EdgeInsets edgeInsetsAll8 = EdgeInsets.all(s8);
  static const EdgeInsets edgeInsetsAll16 = EdgeInsets.all(s16);
  static const EdgeInsets edgeInsetsScreen = EdgeInsets.symmetric(horizontal: screenMargin, vertical: s16);
  static const EdgeInsets edgeInsetsScreenLarge = EdgeInsets.all(screenMarginLarge);

  // ═══════════════════════════════════════════════════════════════════════════
  // FUTURISTIC SHADOWS - Premium depth system
  // ═══════════════════════════════════════════════════════════════════════════
  
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: -1,
    ),
  ];

  static List<BoxShadow> premiumShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  // Elevated card shadow - for cards that need to stand out
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 32,
      offset: const Offset(0, 16),
      spreadRadius: -6,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // Glow shadow - for buttons and CTAs
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  // Subtle inner shadow effect (simulated)
  static List<BoxShadow> innerShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
}
