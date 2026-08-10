// ─────────────────────────────────────────
// Widget: CategoriesRowWidget
// Description: Horizontal scrollable row of cuisine category icons
//              on the home screen. Taps navigate to filtered listings.
// Contains: Category icon + label, horizontal scroll
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import '../../../dishes/dishes_screen/dishes_screens.dart';

class CategoriesRow extends StatelessWidget {
  const CategoriesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        "image":
            'assets/illustrations/category_row/Give Gift Box Illustration.png',
        "label": 'category_donate'.tr(),
        "filter": 'donate'
      },
      // SELL FEATURE DISABLED - Only donate and exchange available
      // {
      //   "image": 'assets/illustrations/category_row/Transaction Illustration.png',
      //   "label": 'category_sell'.tr(),
      //   "filter": 'sell'
      // },
      {
        "image":
            'assets/illustrations/category_row/Hand Shake Illustration.png',
        "label": 'category_exchange'.tr(),
        "filter": 'exchange'
      },
      {
        "image": 'assets/illustrations/category_row/Cheeseburger 3D Icon.png',
        "label": 'category_main_course'.tr(),
        "filter": 'main_course'
      },
      {
        "image": 'assets/illustrations/category_row/3D Ramen Noodles Icon.png',
        "label": 'category_snack'.tr(),
        "filter": 'snack'
      },
      {
        "image": 'assets/illustrations/category_row/vegitables.webp',
        "label": 'category_fresh_food'.tr(),
        "filter": 'fresh_food'
      },
      {
        "image":
            'assets/illustrations/category_row/Strawberry Cake Illustration.png',
        "label": 'category_desserts'.tr(),
        "filter": 'desserts'
      },
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMarginLarge - 4),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return _buildActionButton(
            context,
            category["image"]!,
            category["label"]!,
            category["filter"]!,
          );
        },
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String imagePath,
      String localizedLabel, String filterKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DishesScreen(initialFilter: filterKey),
                ),
              );
            },
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            localizedLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
