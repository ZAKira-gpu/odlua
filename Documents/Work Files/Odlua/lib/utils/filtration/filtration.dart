import 'package:odlua/utils/models/dish_model.dart';

class FiltrationService {
  List<Dish> filterDishes({
    required List<Dish> dishes,
    required List<String> userAllergies,
    String searchQuery = '',
    double maxPrice = 1000,
    double minRating = 0,
    List<String> selectedTags = const [],
    String selectedCategory = 'all',
  }) {
    return dishes.where((dish) {
      if (!_isDishSafe(dish, userAllergies)) return false;
      if (!dish.isAvailable) return false;
      if (searchQuery.isNotEmpty && !_matchesSearch(dish, searchQuery)) return false;
      if (dish.price > maxPrice) return false;
      if (dish.rating < minRating) return false;
      if (selectedTags.isNotEmpty && !_matchesTags(dish, selectedTags)) return false;
      if (selectedCategory != 'all' && !_matchesCategory(dish, selectedCategory)) return false;
      return true;
    }).toList();
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

  bool _matchesSearch(Dish dish, String query) {
    final lowercaseQuery = query.toLowerCase();
    return dish.name.toLowerCase().contains(lowercaseQuery) ||
        dish.description.toLowerCase().contains(lowercaseQuery) ||
        dish.chefName.toLowerCase().contains(lowercaseQuery) ||
        dish.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
  }

  bool _matchesTags(Dish dish, List<String> selectedTags) {
    return selectedTags.any((tag) => dish.tags.contains(tag));
  }

  bool _matchesCategory(Dish dish, String category) {
    return dish.category.toLowerCase() == category.toLowerCase() ||
        dish.availabilityType.toLowerCase() == category.toLowerCase();
  }

  List<Dish> sortByDistance(List<Dish> dishes) {
    dishes.sort((a, b) {
      final aHasDistance = a.hasDistance && a.distance >= 0;
      final bHasDistance = b.hasDistance && b.distance >= 0;

      if (aHasDistance && bHasDistance) {
        return a.distance.compareTo(b.distance);
      } else if (aHasDistance) {
        return -1;
      } else if (bHasDistance) {
        return 1;
      }
      return b.rating.compareTo(a.rating);
    });
    return dishes;
  }
}