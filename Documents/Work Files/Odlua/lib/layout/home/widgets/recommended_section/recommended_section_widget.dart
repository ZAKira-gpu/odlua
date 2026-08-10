import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/layout/dishes/dishes_screen/widgets/dish_card.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/filtration/filtration.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class RecommendedItemsWidget extends StatefulWidget {
  final int? maxItems;
  final bool showTitle;

  const RecommendedItemsWidget({
    super.key,
    this.maxItems = 10,
    this.showTitle = true,
  });

  @override
  State<RecommendedItemsWidget> createState() => _RecommendedItemsWidgetState();
}

class _RecommendedItemsWidgetState extends State<RecommendedItemsWidget> {
  final LocationService _locationService = LocationService();
  final DishService _dishService = DishService();
  late FiltrationService _filtrationService;
  List<String> _userAllergies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filtrationService = FiltrationService();
    _loadUserData();
    _setupLocationService();
  }

  void _setupLocationService() {
    _locationService.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _locationService.getCurrentLocation();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final allergies = data?['allergies'] as List<dynamic>? ?? [];
        setState(() {
          _userAllergies = allergies.whereType<String>().toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      DebugHelper.logError("recommended.error_loading_user_data".tr(),
          error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading) _buildLoadingState() else _buildDishesStream(),
      ],
    );
  }

  Widget _buildDishesStream() {
    return StreamBuilder<List<Dish>>(
      stream: _dishService.getAllDishes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('recommended.error_loading_dishes'.tr());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        try {
          List<Dish> dishesWithDistance =
              _calculateDishDistances(snapshot.data!);
          List<Dish> filteredDishes = _filtrationService.filterDishes(
            dishes: dishesWithDistance,
            userAllergies: _userAllergies,
            searchQuery: '',
            maxPrice: 100.0,
            minRating: 0.0,
            selectedTags: [],
            selectedCategory: 'all',
          );

          // Sort by rating and distance for recommendations
          filteredDishes.sort((a, b) {
            // First by rating (descending)
            final ratingComparison = b.rating.compareTo(a.rating);
            if (ratingComparison != 0) return ratingComparison;

            // Then by distance (ascending)
            if (a.hasDistance && b.hasDistance) {
              return a.distance.compareTo(b.distance);
            }
            return 0;
          });

          // Take only recommended number of items
          final recommendedDishes = widget.maxItems != null
              ? filteredDishes.take(widget.maxItems!).toList()
              : filteredDishes;

          return _buildDishesList(recommendedDishes);
        } catch (e) {
          DebugHelper.logError('recommended.error_processing_dishes'.tr(),
              error: e);
          return _buildErrorState('recommended.error_processing_dishes'.tr());
        }
      },
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

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('recommended.loading_recommendations'.tr()),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                _loadUserData();
                _locationService.refreshLocation();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: Text('recommended.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'recommended.no_recommendations_available'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_userAllergies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'recommended.some_dishes_filtered_due_to_allergies'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDishesList(List<Dish> dishes) {
    if (dishes.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dishes.map((dish) {
          return Container(
            width: 385,
            margin: const EdgeInsets.all(16),
            child: DishCard(
              dish: dish,
              onCardTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DishDetailsScreen(dish: dish)),
              ),
              onChefNameTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChefProfileScreen(chefId: dish.chefId)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.onStateChanged = null;
    super.dispose();
  }
}
