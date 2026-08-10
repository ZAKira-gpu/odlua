// ─────────────────────────────────────────
// Theme: CustomTextFieldTheme
// Description: Input field decoration for light and dark modes.
// Contains: lightInputDecorationTheme, darkInputDecorationTheme
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class NTextFormFieldTheme {
  NTextFormFieldTheme._();

  // Futuristic input fields with subtle depth and clean borders
  static InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 3,
    prefixIconColor: textTertiary,
    suffixIconColor: textTertiary,
    isDense: false,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    labelStyle: TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
    hintStyle: TextStyle(fontSize: 14, color: hintTextColor, fontWeight: FontWeight.w400),
    errorStyle: TextStyle(fontStyle: FontStyle.normal, fontSize: 12, color: errorMessageColor),
    floatingLabelStyle: TextStyle(color: mainColor, fontSize: 13, fontWeight: FontWeight.w600),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(width: 1.5, color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(width: 1.5, color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(width: 2, color: mainColor),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(width: 1.5, color: errorMessageColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(width: 2, color: errorMessageColor),
    ),
  );

  static InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 3,
    prefixIconColor: Colors.grey,
    suffixIconColor: Colors.grey,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    labelStyle: const TextStyle().copyWith(fontSize: 13, color: Colors.white),
    hintStyle: const TextStyle().copyWith(fontSize: 13, color: Colors.grey),
    errorStyle: const TextStyle().copyWith(fontStyle: FontStyle.normal, fontSize: 11),
    floatingLabelStyle: const TextStyle().copyWith(color: Colors.white70, fontSize: 12),
    border: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(width: 1, color: Colors.grey),
    ),
    enabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(width: 1, color: Colors.grey),
    ),
    focusedBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(width: 1, color: Colors.white),
    ),
    errorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(width: 1, color: Colors.red),
    ),
    focusedErrorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(width: 2, color: Colors.orange),
    ),
  );

}