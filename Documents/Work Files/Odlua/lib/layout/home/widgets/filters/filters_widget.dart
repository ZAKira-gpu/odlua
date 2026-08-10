import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../utils/theme/custom_themes/main_colors.dart';

class ClickableFiltersWidget extends StatelessWidget {
  const ClickableFiltersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [
      'filters.asian'.tr(),
      'filters.arabic'.tr(),
      'filters.vegan'.tr(),
      'filters.halal'.tr(),
    ];

    return GestureDetector(
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: index == 0 ? mainColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                categories[index],
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: index == 0 ? Colors.white : Colors.black,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}