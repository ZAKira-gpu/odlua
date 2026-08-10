// ─────────────────────────────────────────
// Theme: CustomChipTheme
// Description: Chip styling for tags and filters.
// Contains: lightChipTheme, darkChipTheme
// ─────────────────────────────────────────

import 'package:flutter/material.dart';

class NChipTheme {
  NChipTheme._();

  static ChipThemeData lightChipThemeData = ChipThemeData(
    disabledColor: Colors.grey.withValues(alpha: 0.4),
    labelStyle: const TextStyle(color: Colors.black, fontSize: 12),
    selectedColor: Colors.blue,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    checkmarkColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );

  static ChipThemeData DarkChipThemeData = ChipThemeData(
    disabledColor: Colors.grey,
    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
    selectedColor: Colors.blue,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    checkmarkColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}