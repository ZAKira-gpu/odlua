// ─────────────────────────────────────────
// Widget: SearchBarWidget
// Description: Home-screen search bar that navigates to SearchResultsScreen.
// Contains: Search input, navigation trigger
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/search/search_results_screen.dart';

class HomeSearchBarWidget extends StatelessWidget {
  const HomeSearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToDishesScreen(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMarginLarge),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Row(
            children: [
              Icon(Iconsax.search_normal_1, color: mainColor, size: 20),
              const SizedBox(width: AppSpacing.s12),
              Text(
                'search.search_placeholder'.tr(),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Iconsax.setting_4, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDishesScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchResultsScreen()),
    );
  }
}
