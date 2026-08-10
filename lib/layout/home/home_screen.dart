// ─────────────────────────────────────────
// Screen: HomeScreen
// Description: Main landing screen after login. Assembles the header,
//              promotional banner carousel, category row, featured
//              dishes, and personalised recommendations.
// Contains: HomeBanner, CategoriesRow, FeaturedSection, Recommended
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/home/widgets/categories_row/categories_row_widget.dart';
import 'package:odlua/layout/home/widgets/header/home_header_widget.dart';
import 'package:odlua/layout/home/widgets/header/search_bar_widget.dart';
import 'package:odlua/layout/home/widgets/featured_today_section/featured_items_widget.dart'
    as featured_today;
import 'package:odlua/layout/home/widgets/recommended_section/recommended_section_widget.dart';
import 'package:odlua/layout/home/widgets/banner/home_banner_widget.dart';
import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import '../../utils/theme/custom_themes/main_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refreshHome() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          color: mainColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.s12),
                const HomeHeaderWidget(),
                const SizedBox(height: AppSpacing.s16),
                const HomeSearchBarWidget(),
                const SizedBox(height: AppSpacing.s20),
                const CategoriesRow(),
                const SizedBox(height: AppSpacing.s12),
                const HomeBannerWidget(),
                const SizedBox(height: AppSpacing.s12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMarginLarge),
                  child: Text(
                    'home.featured_today'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                const featured_today.FeaturedItemsWidget(),
                const SizedBox(height: AppSpacing.s16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMarginLarge),
                  child: Text(
                    'home.recommended_section_title'.tr(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const RecommendedItemsWidget(),
                const SizedBox(height: AppSpacing.s24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
