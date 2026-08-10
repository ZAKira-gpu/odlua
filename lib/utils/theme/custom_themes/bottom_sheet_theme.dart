// ─────────────────────────────────────────
// Theme: CustomBottomSheetTheme
// Description: Bottom-sheet styling for light and dark modes.
// Contains: lightBottomSheetTheme, darkBottomSheetTheme
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class NBottomSheetTheme {
  NBottomSheetTheme._();

  static BottomSheetThemeData lightBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: backgroundColor,
    modalBackgroundColor: backgroundColor,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    )),
  );

  static BottomSheetThemeData darkBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: backgroundColor,
    modalBackgroundColor: backgroundColor,
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    )),
  );
}
