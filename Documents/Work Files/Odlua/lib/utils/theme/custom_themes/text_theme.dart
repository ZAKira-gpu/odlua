import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class AppTextTheme {
  AppTextTheme._();
/// Customizable Light Text Theme
static TextTheme lightTextTheme = TextTheme(
  headlineLarge: const TextStyle().copyWith(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: mainColor,
  ),
  headlineMedium: const TextStyle().copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: mainColor,
  ),
  headlineSmall: const TextStyle().copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: mainColor,
  ),

  titleLarge: const TextStyle().copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: mainColor,
  ),
  titleMedium: const TextStyle().copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: mainColor,
  ),
  titleSmall: const TextStyle().copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: mainColor,
  ),

  bodyLarge: const TextStyle().copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: mainColor,
  ),
  bodyMedium: const TextStyle().copyWith(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: mainColor,
  ),
  bodySmall: const TextStyle().copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: mainColor.withOpacity(0.5),
  ),

  labelLarge: const TextStyle().copyWith(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: mainColor,
  ),
  labelMedium: const TextStyle().copyWith(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: mainColor.withOpacity(0.5),
  ),
);

  ///Customizable Dark Text Theme
  static TextTheme darkTextTheme = TextTheme(
    headlineLarge: const TextStyle().copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
    headlineMedium: const TextStyle().copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
    headlineSmall: const TextStyle().copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),

    titleLarge: const TextStyle().copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
    titleMedium: const TextStyle().copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
    titleSmall: const TextStyle().copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),

    bodyLarge: const TextStyle().copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
    bodyMedium: const TextStyle().copyWith(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white),
    bodySmall: const TextStyle().copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5)),

    labelLarge: const TextStyle().copyWith(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white),
    labelMedium: const TextStyle().copyWith(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white.withOpacity(0.5)),
  );
}