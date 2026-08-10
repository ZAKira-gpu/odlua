import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/layout/dishes/dishes_screen/widgets/dish_card.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';

class RecommendedItemsWidget extends StatefulWidget {
  const RecommendedItemsWidget({super.key});

  @override
  State<RecommendedItemsWidget> createState() => _RecommendedItemsWidgetState();
}

class _RecommendedItemsWidgetState extends State<RecommendedItemsWidget> {
  final DishService _dishService = DishService();
  final LocationService _locationService = LocationService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dish>>(
      stream: _locationService.hasLocation
          ? _dishService.getAllDishesWithDistance(_locationService)
          : _dishService.getAllDishes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading dishes'.tr()));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No dishes available'.tr()));
        }

        List<Dish> dishes = snapshot.data!
            .where((dish) => dish.isAvailable)
            .toList();

        // Sort by distance if available
        if (_locationService.hasLocation) {
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
            return 0;
          });
        }

        if (dishes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No dishes available'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: dishes.map((dish) {
            return DishCard(
              dish: dish,
              onCardTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DishDetailsScreen(dish: dish),
                ),
              ),
              onChefNameTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChefProfileScreen(chefId: dish.chefId),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}