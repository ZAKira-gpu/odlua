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

  // Only light theme - app is forced to light mode only
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
  );
}
