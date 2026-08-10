// ─────────────────────────────────────────
// Widget: LanguageSwitcherTile
// Description: Settings tile that opens a language selection dialog
//              (EN, AR, DE, FR). Switches EasyLocalization locale.
// Contains: ListTile, language dialog, locale setter
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:iconsax/iconsax.dart'; // For arrow icon
import '../../../../utils/theme/custom_themes/main_colors.dart'; // Adjust path as needed

class LanguageSwitcherTile extends StatelessWidget {
  final bool isGrouped;

  const LanguageSwitcherTile({super.key, this.isGrouped = false});

  @override
  Widget build(BuildContext context) {
    final List<Locale> supportedLocales = context.supportedLocales;
    final currentLocale = context.locale;

    return Container(
      margin: isGrouped ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      padding: isGrouped
          ? const EdgeInsets.symmetric(horizontal: 0, vertical: 0)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: isGrouped
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Locale>(
          isExpanded: true,
          value: currentLocale,
          icon: const Icon(Iconsax.arrow_right_3, color: Colors.grey),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(20),
          onChanged: (Locale? selectedLocale) {
            if (selectedLocale != null) {
              context.setLocale(selectedLocale);
            }
          },
          items: supportedLocales.map((locale) {
            return DropdownMenuItem<Locale>(
              value: locale,
              child: Row(
                children: [
                  Text(
                    _getFlag(locale.languageCode),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getLanguageName(locale.languageCode),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return supportedLocales.map((locale) {
              return Row(
                children: [
                  Icon(Icons.language, color: mainColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'profile_select_language'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  /// Emoji flags
  String _getFlag(String lang) {
    switch (lang) {
      case 'en':
        return '🇺🇸';
      case 'ar':
        return '🇸🇦';
      case 'de':
        return '🇩🇪';
      case 'fr':
        return '🇫🇷';
      default:
        return '🌐';
    }
  }

  /// Language names
  String _getLanguageName(String lang) {
    switch (lang) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      default:
        return 'Unknown';
    }
  }
}
