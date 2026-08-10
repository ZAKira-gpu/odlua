// ─────────────────────────────────────────
// Theme: AppTheme
// Description: Main Material theme configuration.
// Contains: lightTheme, darkTheme, custom sub-themes
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'custom_themes/app_bar_theme.dart';
import 'custom_themes/bottom_sheet_theme.dart';
import 'custom_themes/checkbox_theme.dart';
import 'custom_themes/chip_theme.dart';
import 'custom_themes/elevated_button_theme.dart';
import 'custom_themes/outlined_button_theme.dart';
import 'custom_themes/text_field_theme.dart';
import 'custom_themes/text_theme.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // FUTURISTIC THEME - Premium Modern Design System
  // ═══════════════════════════════════════════════════════════════════════════

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'MainFont',
    brightness: Brightness.light,
    primaryColor: mainColor,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: AppTextTheme.lightTextTheme,
    chipTheme: NChipTheme.lightChipThemeData,
    appBarTheme: NAppBarTheme.lightAppBarTheme,
    checkboxTheme: NCheckBoxTheme.lightCheckboxTheme,
    bottomSheetTheme: NBottomSheetTheme.lightBottomSheetTheme,
    elevatedButtonTheme: NElevatedButtonTheme.lightElevatedButtonTheme,
    outlinedButtonTheme: NOutlinedButtonTheme.lightOutlineButtonTheme,
    inputDecorationTheme: NTextFormFieldTheme.lightInputDecorationTheme,
    
    // Premium card styling with subtle depth
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      color: surfaceColor,
      shadowColor: shadow,
      surfaceTintColor: Colors.transparent,
    ),
    
    // Modern dialog design
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: surfaceColor,
      elevation: 8,
      shadowColor: shadow,
      titleTextStyle: TextStyle(
        fontSize: 20, 
        fontWeight: FontWeight.w700, 
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      contentTextStyle: TextStyle(
        fontSize: 15,
        color: textSecondary,
        height: 1.5,
      ),
    ),
    
    // Floating action button styling
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: mainColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    
    // Divider styling
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade100,
      thickness: 1,
      space: 1,
    ),
    
    // Icon theme
    iconTheme: IconThemeData(
      color: textSecondary,
      size: 24,
    ),
    
    // ListTile styling
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: Colors.transparent,
      iconColor: textSecondary,
    ),

    // Snackbar styling
    snackBarTheme: SnackBarThemeData(
      backgroundColor: textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    // Color scheme for Material 3
    colorScheme: ColorScheme.light(
      primary: mainColor,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorMessageColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
  );
}
