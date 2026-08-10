// ─────────────────────────────────────────
// Utility: Filtration
// Description: Client-side dish filtering by category, price, distance.
// Contains: filterDishes, sort helpers, category match
// ─────────────────────────────────────────

import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class FiltrationService {
  /// Applies a 10-step client-side filter chain to the dish list.
  ///
  /// Order: expired → city → distance → allergy → availability →
  /// search → price → rating → tags → category.
  /// Returns a new filtered list (does not mutate input).
  List<Dish> filterDishes({
    required List<Dish> dishes,
    required List<String> userAllergies,
    String searchQuery = '',
    double maxPrice = 1000,
    double minRating = 0,
    List<String> selectedTags = const [],
    String selectedCategory = 'all',
    String selectedCity = '',
    double maxDistance = double.infinity,
  }) {
    DebugHelper.log(
        '🔍 FiltrationService: Filtering ${dishes.length} dishes...');

    int expiredCount = 0;
    int unavailableCount = 0;
    int cityFilteredCount = 0;
    int distanceFilteredCount = 0;
    int allergyFilteredCount = 0;
    int priceFilteredCount = 0;
    int ratingFilteredCount = 0;
    int searchFilteredCount = 0;
    int tagsFilteredCount = 0;
    int categoryFilteredCount = 0;

    final result = dishes.where((dish) {
      // Filter out expired dishes first
      if (dish.isExpired) {
        expiredCount++;
        return false;
      }

      // If selectedCity is provided, only include dishes from that city or matching postal code
      if (selectedCity.isNotEmpty) {
        final dishCity = (dish.city ?? '').toString().toLowerCase();
        final dishPostal = (dish.postalCode ?? '').toString().toLowerCase();
        final sel = selectedCity.toLowerCase();
        if (dishCity != sel && dishPostal != sel) {
          cityFilteredCount++;
          return false;
        }
      }

      // If maxDistance is set, filter by distance when available
      // Only apply distance filter if dish has a valid distance calculated
      if (maxDistance.isFinite && maxDistance > 0) {
        if (dish.hasDistance && dish.distance >= 0) {
          if (dish.distance > maxDistance) {
            distanceFilteredCount++;
            return false;
          }
        }
      }
      if (!_isDishSafe(dish, userAllergies)) {
        allergyFilteredCount++;
        return false;
      }
      if (!dish.isAvailable) {
        unavailableCount++;
        return false;
      }
      if (searchQuery.isNotEmpty && !_matchesSearch(dish, searchQuery)) {
        searchFilteredCount++;
        return false;
      }
      if (dish.price > maxPrice) {
        priceFilteredCount++;
        return false;
      }
      if (dish.rating < minRating) {
        ratingFilteredCount++;
        return false;
      }
      if (selectedTags.isNotEmpty && !_matchesTags(dish, selectedTags)) {
        tagsFilteredCount++;
        return false;
      }
      if (selectedCategory != 'all' &&
          !_matchesCategory(dish, selectedCategory)) {
        categoryFilteredCount++;
        return false;
      }
      return true;
    }).toList();

    DebugHelper.log('🔍 FiltrationService: Filter Results:');
    DebugHelper.log('   - Expired: $expiredCount');
    DebugHelper.log('   - Unavailable: $unavailableCount');
    DebugHelper.log('   - City filtered: $cityFilteredCount');
    DebugHelper.log('   - Distance filtered: $distanceFilteredCount');
    DebugHelper.log('   - Allergy filtered: $allergyFilteredCount');
    DebugHelper.log('   - Price filtered: $priceFilteredCount');
    DebugHelper.log('   - Rating filtered: $ratingFilteredCount');
    DebugHelper.log('   - Search filtered: $searchFilteredCount');
    DebugHelper.log('   - Tags filtered: $tagsFilteredCount');
    DebugHelper.log('   - Category filtered: $categoryFilteredCount');
    DebugHelper.log('   ✅ Passed: ${result.length}');

    return result;
  }

  /// Returns true if the dish contains none of the user’s flagged allergens.
  bool _isDishSafe(Dish dish, List<String> userAllergies) {
    if (userAllergies.isEmpty) return true;
    final dishAllergies = dish.allergies ?? {};
    for (String userAllergy in userAllergies) {
      if (dishAllergies.containsKey(userAllergy) &&
          dishAllergies[userAllergy] == true) {
        return false;
      }
    }
    return true;
  }

  /// Full-text search across name, description, chef, city, postal code, and tags.
  bool _matchesSearch(Dish dish, String query) {
    final lowercaseQuery = query.toLowerCase();
    return dish.name.toLowerCase().contains(lowercaseQuery) ||
        dish.description.toLowerCase().contains(lowercaseQuery) ||
        dish.chefName.toLowerCase().contains(lowercaseQuery) ||
        (dish.city != null &&
            dish.city!.toLowerCase().contains(lowercaseQuery)) ||
        (dish.postalCode != null &&
            dish.postalCode!.toLowerCase().contains(lowercaseQuery)) ||
        dish.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
  }

  bool _matchesTags(Dish dish, List<String> selectedTags) {
    return selectedTags.any((tag) => dish.tags.contains(tag));
  }

  /// Distinguishes availability-type filters (donate, exchange) from food-category filters.
  /// Availability types check `dish.availabilityType`; everything else checks `dish.category`.
  bool _matchesCategory(Dish dish, String category) {
    final lowerCategory = category.toLowerCase();

    // #Ref1: Strict Availability Filtering
    // Availability type filters (donate, exchange) - check availabilityType ONLY
    // SELL FEATURE DISABLED - Only donate and exchange available
    const availabilityTypes = ['donate', 'exchange']; // Removed 'sell'
    if (availabilityTypes.contains(lowerCategory)) {
      // Must match exactly. "Exchange" should not show "Free" items unless they are ALSO "Exchange".
      // Previous logic was lenient, but Refined UX Spec demands strictness.
      return dish.availabilityType.toLowerCase() == lowerCategory;
    }

    // Food category filters (main_course, dessert, etc) - check category ONLY
    return dish.category.toLowerCase() == lowerCategory;
  }

  /// Sort dishes by newest first.
  /// Distance is only used as a tie-breaker when creation times match.
  /// Returns a new sorted list without modifying the input list.
  List<Dish> sortNewestFirst(List<Dish> dishes) {
    // Create a copy to avoid modifying the original list (immutable operation)
    final sortedDishes = List<Dish>.from(dishes);

    sortedDishes.sort((a, b) {
      final createdAtCompare = b.createdAt.compareTo(a.createdAt);
      if (createdAtCompare != 0) return createdAtCompare;

      final aHasDistance = a.hasDistance && a.distance >= 0;
      final bHasDistance = b.hasDistance && b.distance >= 0;

      if (aHasDistance && bHasDistance) {
        return a.distance.compareTo(b.distance);
      } else if (aHasDistance) {
        return -1;
      } else if (bHasDistance) {
        return 1;
      }
      return 0;
    });
    return sortedDishes;
  }
}
