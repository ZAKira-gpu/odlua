// ─────────────────────────────────────────
// Theme: CustomElevatedButtonTheme
// Description: Elevated-button styling for primary CTAs.
// Contains: lightElevatedButtonTheme, darkElevatedButtonTheme
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class NElevatedButtonTheme{
  NElevatedButtonTheme._();

  /// -- Light Theme - Futuristic premium buttons
  static final lightElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: mainColor,
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.grey.shade400,
      disabledBackgroundColor: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
      textStyle: const TextStyle(
        fontSize: 15, 
        color: Colors.white, 
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: mainColor.withValues(alpha: 0.3),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.05);
        }
        return null;
      }),
    ),
  );

  /// -- dark Theme - More circular with reduced padding
  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue,
      disabledForegroundColor: Colors.grey,
      disabledBackgroundColor: Colors.grey,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      textStyle: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  );
}