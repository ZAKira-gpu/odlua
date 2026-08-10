// ─────────────────────────────────────────
// Theme: MainColors
// Description: Primary brand colour (#197533) and derived palette.
// Contains: mainColor, MaterialColor swatch
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FUTURISTIC COLOR SYSTEM - Premium & Modern
// ═══════════════════════════════════════════════════════════════════════════════

// Primary brand color - rich emerald green
var mainColor = HexColor('#1B5E3C');
var mainColorLight = HexColor('#2E8B57');
var mainColorDark = HexColor('#0D3D25');

// Accent colors for highlights
var accentColor = HexColor('#00D9A5'); // Vibrant teal
var accentGold = HexColor('#FFB347'); // Warm gold
var secondaryColor = HexColor('#E13D6B');

// Background system - subtle depth
var backgroundColor = HexColor('#FAFBFC');
var secondaryBackgroundColor = HexColor('#F0F2F5');
var surfaceColor = HexColor('#FFFFFF');
var cardColor = HexColor('#FFFFFF');

// Text hierarchy - proper contrast
var textPrimary = HexColor('#0A0A0A');
var textSecondary = HexColor('#4A5568');
var textTertiary = HexColor('#718096');
var textColor = HexColor('#1A1A1A');
var secondaryTextColor = HexColor('#64748B');

// Status colors - vibrant feedback
var successMessageColor = HexColor('#10B981');
var warningMessageColor = HexColor('#F59E0B');
var errorMessageColor = HexColor('#EF4444');
var infoColor = HexColor('#3B82F6');

var primaryButtonColor = mainColor;
var secondaryButtonColor = HexColor('#10B981');

// Premium shadows
var shadow = Colors.black.withValues(alpha: 0.08);
var shadowLight = Colors.black.withValues(alpha: 0.04);
var shadowMedium = Colors.black.withValues(alpha: 0.12);
var hintTextColor = HexColor('#9CA3AF');

// Glassmorphism colors
var glassWhite = Colors.white.withValues(alpha: 0.7);
var glassBorder = Colors.white.withValues(alpha: 0.2);








// var lightTextColor = Colors.black;
// var darkTextColor = Colors.white;
// // var mainColor = const Color(0xFFF94144);
// // var mainColor = const Color(0xFFFFA729);
// var mainColor = const Color(0xFF556b2f);
// var secondaryColor = const Color(0xFF9370db);
// var backgroundColor = const Color(0xFFFFFFFF);
// // var backgroundColor = const Color(0xFFFDF6EC);