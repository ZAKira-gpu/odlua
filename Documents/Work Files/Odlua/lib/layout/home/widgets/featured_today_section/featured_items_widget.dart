import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class FeaturedItemsWidget extends StatefulWidget {
  const FeaturedItemsWidget({super.key});

  @override
  State<FeaturedItemsWidget> createState() => _FeaturedItemsWidgetState();
}

class _FeaturedItemsWidgetState extends State<FeaturedItemsWidget> {
  final LocationService _locationService = LocationService();
  final DishService _dishService = DishService();
  List<String> _userAllergies = [];

  @override
  void initState() {
    super.initState();
    _loadUserAllergies();
    _setupLocationService();
  }

  void _setupLocationService() {
    _locationService.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _locationService.getCurrentLocation();
  }

  Future<void> _loadUserAllergies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final allergies = data?['allergies'] as List<dynamic>? ?? [];
        setState(() => _userAllergies = allergies.whereType<String>().toList());
      }
    } catch (e) {
      DebugHelper.logError("featured.error_loading_allergies".tr(), error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLocationStatus(),
        StreamBuilder<List<Dish>>(
          stream: _dishService.getAllDishes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState('featured.error_loading_dishes'.tr());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildErrorState('featured.no_dishes_available'.tr());
            }

            List<Dish> dishesWithDistance =
                _calculateDishDistances(snapshot.data!);
            List<Dish> featuredDishes = _getFeaturedDishes(dishesWithDistance);

            if (featuredDishes.isEmpty) {
              return _buildErrorState('featured.no_matching_dishes'.tr());
            }

            return SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: featuredDishes.length,
                itemBuilder: (context, index) =>
                    _buildDishCard(context, featuredDishes[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Dish> _calculateDishDistances(List<Dish> dishes) {
    if (!_locationService.hasLocation) return dishes;

    return dishes.map((dish) {
      if (dish.hasCoordinates) {
        final distance = _locationService.calculateDistance(
          _locationService.currentPosition!.latitude,
          _locationService.currentPosition!.longitude,
          dish.latitude!,
          dish.longitude!,
        );
        return dish.copyWith(distance: distance);
      }
      return dish;
    }).toList();
  }

  List<Dish> _getFeaturedDishes(List<Dish> dishes) {
    List<Dish> safeDishes = dishes.where((dish) {
      if (!_isDishSafeForUser(dish)) return false;
      return dish.isAvailable;
    }).toList();

    safeDishes.sort((a, b) {
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

    return safeDishes.length > 5 ? safeDishes.sublist(0, 5) : safeDishes;
  }

  bool _isDishSafeForUser(Dish dish) {
    if (_userAllergies.isEmpty) return true;
    final dishAllergies = dish.allergies ?? {};
    for (String userAllergy in _userAllergies) {
      if (dishAllergies.containsKey(userAllergy) &&
          dishAllergies[userAllergy] == true) {
        return false;
      }
    }
    return true;
  }

  Widget _buildLocationStatus() {
    if (_locationService.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text('featured.getting_location'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard(BuildContext context, Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DishDetailsScreen(dish: dish),
          )),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                dish.mainImageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: Colors.grey[200],
                  child:
                      const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1),
                  const SizedBox(height: 4),
                  Text(dish.chefName,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1),
                  const SizedBox(height: 2),
                  Text(_formatPrice(dish.price, dish.currency),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(dish.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      const Icon(Icons.location_on,
                          size: 13, color: Colors.redAccent),
                      const SizedBox(width: 2),
                      Text(_locationService.formatDistance(dish.distance),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price, String currency) {
    if (price == 0) return 'featured.free'.tr();
    return '€${price.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    _locationService.onStateChanged = null;
    super.dispose();
  }
}
