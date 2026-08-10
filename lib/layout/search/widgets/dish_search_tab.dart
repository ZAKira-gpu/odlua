// ─────────────────────────────────────────
// Widget: DishSearchTab
// Description: Tab content showing dish search results.
// Contains: Dish card list, Firestore query
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';

class DishSearchTab extends StatefulWidget {
  final String searchQuery;

  const DishSearchTab({super.key, this.searchQuery = ''});

  @override
  State<DishSearchTab> createState() => _DishSearchTabState();
}

class _DishSearchTabState extends State<DishSearchTab> {
  final DishService _dishService = DishService();

  /// Filter dishes based on search query
  /// Also filters out unavailable and expired dishes
  List<Dish> _filterDishes(List<Dish> dishes) {
    // First filter out unavailable and expired dishes
    final activeDishes =
        dishes.where((dish) => dish.isAvailable && !dish.isExpired).toList();

    if (widget.searchQuery.isEmpty) return activeDishes;

    final query = widget.searchQuery.toLowerCase().trim();
    if (query.isEmpty) return activeDishes;

    return activeDishes.where((dish) {
      // Search in multiple fields with null safety
      final nameMatch = dish.name.toLowerCase().contains(query);
      final descMatch = dish.description.toLowerCase().contains(query);
      final chefMatch = dish.chefName.toLowerCase().contains(query);
      final categoryMatch = dish.category.toLowerCase().contains(query);
      final tagMatch =
          dish.tags.any((tag) => tag.toLowerCase().contains(query));
      final cityMatch = dish.city?.toLowerCase().contains(query) ?? false;

      return nameMatch ||
          descMatch ||
          chefMatch ||
          categoryMatch ||
          tagMatch ||
          cityMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dish>>(
      stream: _dishService.getAllDishes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter dishes (includes availability and expiry checks)
        final allDishes = snapshot.data ?? [];
        final filteredDishes = _filterDishes(allDishes);

        if (filteredDishes.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDishes.length,
          itemBuilder: (context, index) {
            return _buildDishCard(filteredDishes[index]);
          },
        );
      },
    );
  }

  Widget _buildDishCard(Dish dish) {
    final imageUrl = dish.imageUrls.isNotEmpty ? dish.imageUrls.first : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DishDetailsScreen(dish: dish),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        dish.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Chef name
                      Row(
                        children: [
                          Icon(
                            Iconsax.user,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dish.chefName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Price and rating removed
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Iconsax.reserve,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.search_normal,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.searchQuery.isEmpty
                ? 'no_dishes_found'.tr()
                : 'no_results_for'.tr(args: [widget.searchQuery]),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'try_different_search'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.warning_2,
              size: 48,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'error_loading_dishes'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
