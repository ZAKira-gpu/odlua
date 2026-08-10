import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';

class RecommendationService {
  final LocationService _locationService;

  RecommendationService(this._locationService);

  Future<List<Dish>> getRecommendedDishes(
    List<Dish> allDishes, 
    List<String> userAllergies, 
    {int limit = 10}
  ) async {
    List<Dish> safeDishes = allDishes.where((dish) {
      return _isDishSafe(dish, userAllergies) && dish.isAvailable;
    }).toList();

    if (_locationService.hasLocation) {
      safeDishes = await _sortByDistance(safeDishes);
    }

    if (safeDishes.length > limit) {
      safeDishes = safeDishes.sublist(0, limit);
    }

    return safeDishes;
  }

  Future<List<Dish>> _sortByDistance(List<Dish> dishes) async {
    final userPosition = _locationService.currentPosition;
    if (userPosition == null) return dishes;

    List<Dish> dishesWithDistance = dishes.map((dish) {
      if (dish.hasCoordinates) {
        final distance = _locationService.calculateDistance(
          userPosition.latitude,
          userPosition.longitude,
          dish.latitude!,
          dish.longitude!,
        );
        return dish.copyWith(distance: distance);
      }
      return dish;
    }).toList();

    dishesWithDistance.sort((a, b) {
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

    return dishesWithDistance;
  }

  bool _isDishSafe(Dish dish, List<String> userAllergies) {
    if (userAllergies.isEmpty) return true;
    final dishAllergies = dish.allergies ?? {};
    for (String userAllergy in userAllergies) {
      if (dishAllergies.containsKey(userAllergy) && dishAllergies[userAllergy] == true) {
        return false;
      }
    }
    return true;
  }

  Future<List<Dish>> getFeaturedDishes(
    List<Dish> allDishes, 
    List<String> userAllergies, 
    {int limit = 5}
  ) async {
    return getRecommendedDishes(allDishes, userAllergies, limit: limit);
  }
}