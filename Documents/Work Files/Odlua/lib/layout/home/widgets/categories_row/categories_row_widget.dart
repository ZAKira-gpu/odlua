import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../dishes/dishes_screen/dishes_screens.dart';

class CategoriesRow extends StatelessWidget {
  const CategoriesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        "image": 'assets/illustrations/category_row/Give Gift Box Illustration.png',
        "label": 'category_donate'.tr(),
        "filter": 'donate'
      },
      {
        "image": 'assets/illustrations/category_row/Transaction Illustration.png',
        "label": 'category_sell'.tr(),
        "filter": 'sell'
      },
      {
        "image": 'assets/illustrations/category_row/Hand Shake Illustration.png',
        "label": 'category_exchange'.tr(),
        "filter": 'exchange'
      },
      {
        "image": 'assets/illustrations/category_row/Breakfast 3D Icons.png',
        "label": 'category_breakfast'.tr(),
        "filter": 'breakfast'
      },
      {
        "image": 'assets/illustrations/category_row/Cheeseburger 3D Icon.png',
        "label": 'category_lunch'.tr(),
        "filter": 'lunch'
      },
      {
        "image": 'assets/illustrations/category_row/3D Ramen Noodles Icon.png',
        "label": 'category_dinner'.tr(),
        "filter": 'dinner'
      },
      {
        "image": 'assets/illustrations/category_row/vegitables.webp',
        "label": 'category_fresh_food'.tr(),
        "filter": 'fresh_food'
      },
      {
        "image": 'assets/illustrations/category_row/Strawberry Cake Illustration.png',
        "label": 'category_desserts'.tr(),
        "filter": 'desserts'
      },
    ];

    return SizedBox(
      height: 100, // height for the scrollable row
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildActionButton(
      BuildContext context, String imagePath, String localizedLabel, String filterKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.4),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(6.0),
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}