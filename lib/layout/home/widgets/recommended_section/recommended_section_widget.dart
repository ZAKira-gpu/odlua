// ─────────────────────────────────────────
// Widget: RecommendedSectionWidget
// Description: Personalised dish recommendations based on user
//              preferences, location, and order history.
// Contains: Recommended item list, Firestore query, shimmer
// ─────────────────────────────────────────

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/layout/dishes/dishes_screen/widgets/dish_card.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/filtration/filtration.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/helpers/user_prefs_cache.dart';
import 'package:odlua/utils/services/moderation_service.dart';

class RecommendedItemsWidget extends StatefulWidget {
  final int? maxItems;
  final bool showTitle;

  const RecommendedItemsWidget({
    super.key,
    this.maxItems = 100,
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
  Set<String> _blockedUserIds = {};
  StreamSubscription<Set<String>>? _blockedSub;
  bool _streamTimedOut = false;

  @override
  void initState() {
    super.initState();
    _filtrationService = FiltrationService();
    _loadUserData();
    _setupLocationService();
    _blockedSub =
        ModerationService.instance.blockedUserIdsStream().listen((ids) {
      if (mounted) setState(() => _blockedUserIds = ids);
    });
    // Safety timeout: if Firestore stream doesn't emit within 5s, show empty state
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_streamTimedOut) {
        setState(() => _streamTimedOut = true);
      }
    });
  }

  void _setupLocationService() {
    _locationService.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _locationService.getCurrentLocation();
  }

  Future<void> _loadUserData() async {
    final allergies = await UserPrefsCache.instance.getAllergies();
    if (mounted) setState(() => _userAllergies = allergies);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDishesStream(),
      ],
    );
  }

  Widget _buildDishesStream() {
    return StreamBuilder<List<Dish>>(
      stream: _dishService.getAllDishes(),
      builder: (context, snapshot) {
        DebugHelper.log(
            '🏠 RecommendedItems: Stream state=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');

        if (snapshot.hasError) {
          DebugHelper.log(
              '🏠 RecommendedItems: ❌ Stream error: ${snapshot.error}');
          return _buildErrorState('recommended.error_loading_dishes'.tr());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_streamTimedOut) {
            // Stream timed out - show empty state instead of infinite spinner
            return _buildEmptyState();
          }
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          DebugHelper.log('🏠 RecommendedItems: ⚠️ No dishes available');
          return _buildEmptyState();
        }

        DebugHelper.log(
            '🏠 RecommendedItems: ✅ Received ${snapshot.data!.length} dishes');

        try {
          List<Dish> dishesWithDistance =
              _calculateDishDistances(snapshot.data!);
          List<Dish> filteredDishes = _filtrationService.filterDishes(
            dishes: dishesWithDistance,
            userAllergies: _userAllergies,
            searchQuery: '',
            maxPrice: double.infinity, // No price limit for recommended dishes
            minRating: 0.0,
            selectedTags: [],
            selectedCategory: 'all',
            selectedCity: '',
            maxDistance: double.infinity,
          );

          // Filter out dishes from blocked chefs
          filteredDishes = filteredDishes
              .where((d) => !_blockedUserIds.contains(d.chefId))
              .toList();

          DebugHelper.log(
              '🏠 RecommendedItems: Filtered to ${filteredDishes.length} dishes (after block filter)');

          // Show newest dishes first. Distance only breaks exact timestamp ties.
          filteredDishes.sort((a, b) {
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

          // Take only recommended number of items
          final recommendedDishes = widget.maxItems != null
              ? filteredDishes.take(widget.maxItems!).toList()
              : filteredDishes;

          DebugHelper.log(
              '🏠 RecommendedItems: Showing ${recommendedDishes.length} dishes');
          return _buildDishesList(recommendedDishes);
        } catch (e, stackTrace) {
          DebugHelper.log('🏠 RecommendedItems: ❌ Error processing dishes: $e');
          DebugHelper.log('🏠 RecommendedItems: Stack trace: $stackTrace');
          return _buildErrorState('recommended.error_processing_dishes'.tr());
        }
      },
    );
  }

  List<Dish> _calculateDishDistances(List<Dish> dishes) {
    if (!_locationService.hasLocation) return dishes;

    return dishes.map((dish) {
      if (dish.hasCoordinates && _locationService.currentPosition != null) {
        final pos = _locationService.currentPosition;
        final lat = (pos?['latitude'] as num? ?? 0.0).toDouble();
        final lng = (pos?['longitude'] as num? ?? 0.0).toDouble();
        final distance = _locationService.calculateDistance(
          lat,
          lng,
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62, // Adjusted to prevent overflow
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: dishes.length,
      itemBuilder: (context, index) {
        final dish = dishes[index];
        return DishCard(
          dish: dish,
          onCardTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DishDetailsScreen(dish: dish)),
          ),
          onChefNameTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChefProfileScreen(chefId: dish.chefId)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _blockedSub?.cancel();
    _locationService.onStateChanged = null;
    super.dispose();
  }
}
