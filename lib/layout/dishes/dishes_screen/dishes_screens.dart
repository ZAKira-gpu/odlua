// ─────────────────────────────────────────
// Screen: DishesScreen (Menu Browse)
// Description: Main dish catalogue with category tabs, search,
//              city-based filtering, and infinite-scroll pagination.
// Contains: Category filters, dish grid, search bar, Firestore queries
// ─────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/dishes/dish_details_screen.dart';
import 'package:odlua/layout/dishes/filters/filters_screen.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/filtration/filtration.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'widgets/dish_card.dart';
import 'widgets/category_filters.dart';
import 'widgets/dish_search_bar.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class DishesScreen extends StatefulWidget {
  final String initialFilter;

  const DishesScreen({super.key, this.initialFilter = 'all'});

  @override
  State<DishesScreen> createState() => _DishesScreenState();
}

class _DishesScreenState extends State<DishesScreen> {
  final LocationService _locationService = LocationService();
  final DishService _dishService = DishService();
  late FiltrationService _filtrationService;

  double _maxPrice = 100.0;
  double _maxDistance = double.infinity; // Show all results, no distance limit
  List<String> _userAllergies = [];
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String _selectedCity = '';
  bool _streamTimedOut = false;

  final List<String> _filters = [
    'all',
    'donate',
    // 'sell', // SELL FEATURE DISABLED
    'exchange',
    'main_course',
    'appetizer',
    'dessert',
    'soup',
    'fresh_food',
    'salad',
    'beverage',
    'snack',
  ];

  @override
  void initState() {
    super.initState();
    DebugHelper.log('🍽️ DishesScreen: Initializing...');
    _selectedFilter = widget.initialFilter.toLowerCase();
    DebugHelper.log('🍽️ DishesScreen: Initial filter = $_selectedFilter');
    _filtrationService = FiltrationService();
    _loadUserAllergies();
    _setupLocationService();
    // Safety timeout: if Firestore stream doesn't emit within 5s, show empty state
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_streamTimedOut) {
        setState(() => _streamTimedOut = true);
      }
    });
  }

  void _setupLocationService() {
    try {
      DebugHelper.log('🍽️ DishesScreen: Setting up location service...');
      _locationService.onStateChanged = () {
        if (mounted) setState(() {});
      };
      _locationService.getCurrentLocation();
      DebugHelper.log('🍽️ DishesScreen: Location service setup complete');
    } catch (e) {
      DebugHelper.log(
          '🍽️ DishesScreen: ❌ Error setting up location service: $e');
    }
  }

  Future<void> _loadUserAllergies() async {
    try {
      DebugHelper.log('🍽️ DishesScreen: Loading user allergies...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        DebugHelper.log('🍽️ DishesScreen: No user logged in');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3),
              onTimeout: () =>
                  throw TimeoutException('User allergies load timeout'));
      if (doc.exists) {
        final data = doc.data();
        final allergies = data?['allergies'] as List<dynamic>? ?? [];
        setState(() {
          _userAllergies = allergies.whereType<String>().toList();
          // Don't pre-select user's city - let them see all dishes by default
          final city = data?['city'] as String? ?? '';
          DebugHelper.log(
              '🍽️ DishesScreen: User city is "$city" but NOT applying city filter (showing all dishes)');
          // Keep _selectedCity empty to show all dishes
        });
        DebugHelper.log(
            '🍽️ DishesScreen: Loaded ${_userAllergies.length} allergies, city filter=$_selectedCity');
      } else {
        DebugHelper.log('🍽️ DishesScreen: User document does not exist');
      }
    } catch (e) {
      DebugHelper.log("🍽️ DishesScreen: ❌ Error loading user allergies: $e");
    }
  }

  void _applyFilters(Map<String, dynamic> filterResults) {
    try {
      DebugHelper.log('🍽️ DishesScreen: Applying filters: $filterResults');
      setState(() {
        _maxPrice = (filterResults['maxPrice'] as double?) ?? 100.0;
        _maxDistance =
            (filterResults['maxDistance'] as num?)?.toDouble() ?? 10.0;
      });
      DebugHelper.log(
          '🍽️ DishesScreen: ✅ Filters applied - maxPrice=$_maxPrice, maxDistance=$_maxDistance');
    } catch (e) {
      DebugHelper.log('🍽️ DishesScreen: ❌ Error applying filters: $e');
      setState(() {
        _maxPrice = 100.0;
        _maxDistance = double.infinity;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedFilter = 'all';
      _maxPrice = 100.0;
      _maxDistance = double.infinity;
    });
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedFilter != 'all' ||
        _maxPrice < 100.0 ||
        _maxDistance < double.infinity; // Changed from 10.0
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DishesScreenSearchBar(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              onSubmitted: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _hasActiveFilters
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.filter_list_rounded,
                  color:
                      _hasActiveFilters ? Colors.blue : Colors.grey.shade600),
              onPressed: () async {
                try {
                  DebugHelper.log(
                      '🍽️ DishesScreen: Opening filters screen...');
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FiltersScreen(
                        currentMaxDistance: _maxDistance,
                      ),
                    ),
                  );
                  if (result != null && mounted) {
                    DebugHelper.log(
                        '🍽️ DishesScreen: Filters returned: $result');
                    _applyFilters(result);
                  } else {
                    DebugHelper.log(
                        '🍽️ DishesScreen: Filters cancelled or no result');
                  }
                } catch (e) {
                  DebugHelper.log('Error navigating to filters: $e');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_rounded, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
              child: Text('filters_active'.tr(),
                  style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: _resetFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('clear_all'.tr(),
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishesStream() {
    DebugHelper.log('🍽️ DishesScreen: Building dishes stream...');
    return StreamBuilder<List<Dish>>(
      stream: _dishService.getAllDishes(),
      builder: (context, snapshot) {
        DebugHelper.log(
            '🍽️ DishesScreen: Stream state = ${snapshot.connectionState}, hasData = ${snapshot.hasData}, hasError = ${snapshot.hasError}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          if (_streamTimedOut) {
            DebugHelper.log(
                '🍽️ DishesScreen: Stream timed out, showing empty state');
            return _buildEmptyState();
          }
          DebugHelper.log('🍽️ DishesScreen: Waiting for data...');
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          DebugHelper.log(
              '🍽️ DishesScreen: ❌ Stream error: ${snapshot.error}');
          return _buildErrorState('error_loading_dishes'.tr());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          DebugHelper.log('🍽️ DishesScreen: ⚠️ No dishes found in Firestore');
          return _buildEmptyState();
        }

        try {
          DebugHelper.log(
              '🍽️ DishesScreen: ✅ Loaded ${snapshot.data!.length} dishes from Firestore');

          List<Dish> dishesWithDistance =
              _calculateDishDistances(snapshot.data!);
          DebugHelper.log(
              '🍽️ DishesScreen: Calculated distances for ${dishesWithDistance.length} dishes');

          List<Dish> filteredDishes = _filtrationService.filterDishes(
            dishes: dishesWithDistance,
            userAllergies: _userAllergies,
            searchQuery: _searchQuery,
            maxPrice: _maxPrice,
            minRating: 0.0, // Rating filter disabled
            selectedTags: [],
            selectedCategory: _selectedFilter,
            selectedCity: _selectedCity,
            maxDistance: _maxDistance,
          );

          DebugHelper.log(
              '🍽️ DishesScreen: 📊 Filtered to ${filteredDishes.length} dishes (category: $_selectedFilter, city: $_selectedCity, maxPrice: €$_maxPrice, maxDistance: ${_maxDistance}km, searchQuery: "$_searchQuery")');

          if (filteredDishes.isEmpty) {
            DebugHelper.log(
                '🍽️ DishesScreen: ⚠️ All dishes filtered out! Check filter criteria.');
          }

          filteredDishes = _filtrationService.sortNewestFirst(filteredDishes);
          return _buildDishesList(filteredDishes);
        } catch (e, stackTrace) {
          DebugHelper.log('🍽️ DishesScreen: ❌ Error processing dishes: $e');
          DebugHelper.log('🍽️ DishesScreen: Stack trace: $stackTrace');
          return _buildErrorState('error_processing_dishes'.tr());
        }
      },
    );
  }

  /// Calculate distances for dishes from user's current location
  /// Returns dishes with calculated distances, or original dishes if location unavailable
  List<Dish> _calculateDishDistances(List<Dish> dishes) {
    if (!_locationService.hasLocation ||
        _locationService.currentPosition == null) {
      DebugHelper.log(
          '🍽️ DishesScreen: Location not available, skipping distance calculation');
      return dishes;
    }

    return dishes.map((dish) {
      try {
        if (!dish.hasCoordinates ||
            dish.latitude == null ||
            dish.longitude == null) {
          return dish;
        }

        final pos = _locationService.currentPosition;
        double? lat;
        double? lng;

        // Safely extract coordinates from position
        if (pos != null) {
          lat = _safeDouble(pos['latitude']);
          lng = _safeDouble(pos['longitude']);
        }

        if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
          return dish;
        }

        final distance = _locationService.calculateDistance(
          lat,
          lng,
          dish.latitude!,
          dish.longitude!,
        );
        return dish.copyWith(distance: distance);
      } catch (e, stackTrace) {
        DebugHelper.log(
            '🍽️ DishesScreen: Error calculating distance for dish ${dish.id}: $e');
        DebugHelper.log('🍽️ DishesScreen: Stack trace: $stackTrace');
        return dish;
      }
    }).toList();
  }

  /// Safely convert dynamic value to double
  double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(mainColor)),
            ),
          ),
          const SizedBox(height: 20),
          Text('loading_dishes'.tr(),
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(message,
                style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Icon(Iconsax.warning_2,
                  size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text('no_dishes_available'.tr(),
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDishesList(List<Dish> dishes) {
    if (dishes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Icon(Iconsax.search_status,
                    size: 40, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              Text('no_matching_dishes'.tr(),
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              if (_userAllergies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('some_dishes_filtered_due_to_allergies'.tr(),
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  'reset_filters'.tr(),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: dishes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) => DishCard(
        dish: dishes[index],
        onCardTap: () => _navigateToDishDetails(dishes[index]),
        onChefNameTap: () => _navigateToChefProfile(dishes[index].chefId),
      ),
    );
  }

  void _navigateToDishDetails(Dish dish) {
    try {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => DishDetailsScreen(dish: dish)));
    } catch (e) {
      DebugHelper.log('Error navigating to dish details: $e');
    }
  }

  void _navigateToChefProfile(String chefId) {
    try {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChefProfileScreen(chefId: chefId)));
    } catch (e) {
      DebugHelper.log('Error navigating to chef profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('dishes'.tr()),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _locationService.refreshLocation();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: mainColor,
        child: Column(
          children: [
            _buildSearchSection(),
            CategoryFilterBar(
              filters: _filters,
              selectedFilter: _selectedFilter,
              onFilterSelected: (filter) =>
                  setState(() => _selectedFilter = filter),
            ),
            if (_hasActiveFilters) _buildActiveFiltersIndicator(),
            Expanded(child: _buildDishesStream()),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.onStateChanged = null;
    super.dispose();
  }
}
