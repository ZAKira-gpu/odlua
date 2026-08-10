import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/home/widgets/categories_row/categories_row_widget.dart';
import 'package:odlua/layout/home/widgets/header/home_header_widget.dart';
import 'package:odlua/layout/home/widgets/header/search_bar_widget.dart';
import 'package:odlua/layout/home/widgets/featured_today_section/featured_items_widget.dart' as featured_today;
import 'package:odlua/layout/home/widgets/recommended_section/recommended_section_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeHeaderWidget(),
              const SizedBox(height: 24),
              const HomeSearchBarWidget(),
              const SizedBox(height: 24),
              const CategoriesRow(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'home.featured_today'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const featured_today.FeaturedItemsWidget(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 6),
                child: Text(
                  'home.recommended_section_title'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const RecommendedItemsWidget(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}