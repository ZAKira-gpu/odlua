// ─────────────────────────────────────────
// Service: RecommendationEngine
// Description: Generates personalised dish recommendations.
// Contains: getRecommendations, scoring algorithm
// ─────────────────────────────────────────

import 'package:geolocator/geolocator.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';

class RecommendationService {
  final LocationService _locationService;

  RecommendationService(this._locationService);

  /// Returns the top [limit] dishes ranked by a multi-factor relevance score.
  ///
  /// Pipeline: filter unsafe (allergy) → score each dish → sort descending → take [limit].
  /// Scoring factors (max 110 pts): distance (30), rating (25), popularity (20),
  /// preference-match (15), freshness (10), price (5), featured flag (5).
  Future<List<Dish>> getRecommendedDishes(
      List<Dish> allDishes, List<String> userAllergies,
      {int limit = 10, List<String>? userPreferences}) async {
    // Filter out dishes with allergens and unavailable dishes
    List<Dish> safeDishes = allDishes.where((dish) {
      return _isDishSafe(dish, userAllergies) && dish.isAvailable;
    }).toList();

    // Score and sort dishes by relevance
    List<_ScoredDish> scoredDishes =
        await _scoreDishes(safeDishes, userPreferences ?? []);
    scoredDishes.sort((a, b) => b.score.compareTo(a.score));

    // Return top dishes
    final topDishes = scoredDishes.take(limit).map((sd) => sd.dish).toList();
    return topDishes;
  }

  /// Score dishes based on multiple factors:
  /// - Distance (closer is better)
  /// - Rating (higher is better)
  /// - Popularity (ratings count)
  /// - User preferences match (category, tags)
  /// - Freshness (recently added dishes get a bonus)
  /// - Price attractiveness
  Future<List<_ScoredDish>> _scoreDishes(
      List<Dish> dishes, List<String> userPreferences) async {
    final userPosition = _locationService.currentPosition as Position?;

    List<_ScoredDish> scoredDishes = [];

    for (var dish in dishes) {
      double score = 0.0;
      double? calculatedDistance;

      // 1. Distance Score (0-30 points)
      if (userPosition != null && dish.hasCoordinates) {
        calculatedDistance = _locationService.calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          dish.latitude!,
          dish.longitude!,
        );

        // Closer dishes get more points (max 30 points for < 1km)
        if (calculatedDistance < 1.0) {
          score += 30.0;
        } else if (calculatedDistance < 5.0) {
          score += 25.0 - (calculatedDistance * 3);
        } else if (calculatedDistance < 10.0) {
          score += 15.0 - (calculatedDistance * 1);
        } else if (calculatedDistance < 20.0) {
          score += 5.0;
        }
      }

      // 2. Rating Score (0-25 points)
      if (dish.rating > 0) {
        score += (dish.rating / 5.0) * 25.0;
      }

      // 3. Popularity Score (0-20 points)
      // Based on ratings count (more ratings = more popular)
      final ratingsScore = (dish.ratingsCount / 50.0).clamp(0.0, 1.0) * 20.0;
      score += ratingsScore;

      // 4. User Preferences Match (0-15 points)
      if (userPreferences.isNotEmpty) {
        final dishCategory = dish.category.toLowerCase();
        final dishTags = dish.tags.map((t) => t.toLowerCase()).toList();

        int matchCount = 0;
        for (final pref in userPreferences) {
          final prefLower = pref.toLowerCase();
          if (dishCategory.contains(prefLower) ||
              dishTags.any((tag) => tag.contains(prefLower))) {
            matchCount++;
          }
        }
        if (userPreferences.isNotEmpty) {
          score += (matchCount / userPreferences.length) * 15.0;
        }
      }

      // 5. Freshness Bonus (0-10 points)
      // Recent dishes (within last 7 days) get a bonus
      final createdDate = dish.createdAt.toDate();
      final daysSinceCreated = DateTime.now().difference(createdDate).inDays;
      if (daysSinceCreated <= 7) {
        score += 10.0 - (daysSinceCreated * 1.4).clamp(0.0, 10.0);
      } else if (daysSinceCreated <= 14) {
        score += 5.0;
      }

      // 6. Price Attractiveness (0-5 points)
      // Mid-range prices get a slight bonus (sweet spot)
      if (dish.price >= 5.0 && dish.price <= 20.0) {
        score += 5.0;
      } else if (dish.price > 20.0 && dish.price <= 30.0) {
        score += 3.0;
      } else if (dish.price < 5.0) {
        score += 2.0;
      }

      // 7. Featured/Recommended Flag Bonus (0-5 points)
      if (dish.isRecommended || dish.isFeatured) {
        score += 5.0;
      }

      // Update dish with distance if calculated
      if (calculatedDistance != null) {
        dish = dish.copyWith(distance: calculatedDistance);
      }

      scoredDishes.add(_ScoredDish(dish, score));
    }

    return scoredDishes;
  }

  /// Returns false if the dish contains any allergen the user has flagged.
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

  /// Convenience wrapper — returns the top 5 recommended dishes.
  Future<List<Dish>> getFeaturedDishes(
      List<Dish> allDishes, List<String> userAllergies,
      {int limit = 5, List<String>? userPreferences}) async {
    return getRecommendedDishes(allDishes, userAllergies,
        limit: limit, userPreferences: userPreferences);
  }
}

/// Helper class to store dish with its calculated score
class _ScoredDish {
  final Dish dish;
  final double score;

  _ScoredDish(this.dish, this.score);
}
