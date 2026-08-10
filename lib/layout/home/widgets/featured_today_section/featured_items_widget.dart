// ─────────────────────────────────────────
// Widget: FeaturedItemsWidget
// Description: Horizontal section of top-rated or editorially picked
//              dishes. Fetches featured items from Firestore.
// Contains: FeaturedItemWidget list, Firestore query, shimmer
// ─────────────────────────────────────────

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/helpers/user_prefs_cache.dart';
import 'package:odlua/utils/services/moderation_service.dart';

class FeaturedItemsWidget extends StatefulWidget {
  const FeaturedItemsWidget({super.key});

  @override
  State<FeaturedItemsWidget> createState() => _FeaturedItemsWidgetState();
}

class _FeaturedItemsWidgetState extends State<FeaturedItemsWidget> {
  final LocationService _locationService = LocationService();
  final DishService _dishService = DishService();
  List<String> _userAllergies = [];
  Set<String> _blockedUserIds = {};
  StreamSubscription<Set<String>>? _blockedSub;
  bool _streamTimedOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserAllergies();
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

  Future<void> _loadUserAllergies() async {
    final allergies = await UserPrefsCache.instance.getAllergies();
    if (mounted) setState(() => _userAllergies = allergies);
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
            DebugHelper.log(
                '🏠 FeaturedItems: Stream state=${snapshot.connectionState}, hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');

            if (snapshot.hasError) {
              DebugHelper.log(
                  '🏠 FeaturedItems: ❌ Stream error: ${snapshot.error}');
              return _buildErrorState('featured.error_loading_dishes'.tr());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              if (_streamTimedOut) {
                // Stream timed out - show empty state instead of infinite spinner
                return _buildErrorState('featured.no_dishes_available'.tr());
              }
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              DebugHelper.log('🏠 FeaturedItems: ⚠️ No dishes available');
              return _buildErrorState('featured.no_dishes_available'.tr());
            }

            DebugHelper.log(
                '🏠 FeaturedItems: ✅ Received ${snapshot.data!.length} dishes');

            try {
              List<Dish> dishesWithDistance =
                  _calculateDishDistances(snapshot.data!);
              List<Dish> featuredDishes =
                  _getFeaturedDishes(dishesWithDistance);

              DebugHelper.log(
                  '🏠 FeaturedItems: Featured ${featuredDishes.length} dishes after filtering');

              if (featuredDishes.isEmpty) {
                return _buildErrorState('featured.no_matching_dishes'.tr());
              }

              return SizedBox(
                height: 218,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: featuredDishes.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                        right: index < featuredDishes.length - 1 ? 10 : 0),
                    child: SizedBox(
                      width: 160,
                      child: _buildDishCard(context, featuredDishes[index]),
                    ),
                  ),
                ),
              );
            } catch (e, stackTrace) {
              DebugHelper.log(
                  '🏠 FeaturedItems: ❌ Error processing dishes: $e');
              DebugHelper.log('🏠 FeaturedItems: Stack trace: $stackTrace');
              return _buildErrorState('featured.error_loading_dishes'.tr());
            }
          },
        ),
      ],
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

  List<Dish> _getFeaturedDishes(List<Dish> dishes) {
    List<Dish> safeDishes = dishes.where((dish) {
      // Filter out expired dishes
      if (dish.isExpired) return false;
      if (!_isDishSafeForUser(dish)) return false;
      // Filter out dishes from blocked chefs
      if (_blockedUserIds.contains(dish.chefId)) return false;
      return dish.isAvailable;
    }).toList();

    // Show newest dishes first. Distance only breaks exact timestamp ties.
    safeDishes.sort((a, b) {
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
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2)
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
                height: 95,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 95,
                  color: Colors.grey[200],
                  child:
                      const Icon(Icons.fastfood, size: 36, color: Colors.grey),
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
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(dish.chefName,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  // Distance row
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 11, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                            _locationService.formatDistance(dish.distance),
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis),
                      ),
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

  @override
  void dispose() {
    _blockedSub?.cancel();
    _locationService.onStateChanged = null;
    super.dispose();
  }
}
