import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  double _minRating = 0.0;
  double _maxDistance = 10.0;
  List<String> _userAllergies = [];
  String _searchQuery = '';
  String _selectedFilter = 'all';

  final List<String> _filters = [
    'all', 'donate', 'sell', 'exchange', 'breakfast', 
    'lunch', 'dinner', 'fresh_food', 'dessert', 'appetizer'
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter.toLowerCase();
    _filtrationService = FiltrationService();
    _loadUserAllergies();
    _setupLocationService();
  }

  void _setupLocationService() {
    try {
      _locationService.onStateChanged = () {
        if (mounted) setState(() {});
      };
      _locationService.getCurrentLocation();
    } catch (e) {
      DebugHelper.log('Error setting up location service: $e');
    }
  }

  Future<void> _loadUserAllergies() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        final allergies = data?['allergies'] as List<dynamic>? ?? [];
        setState(() => _userAllergies = allergies.whereType<String>().toList());
      }
    } catch (e) {
      DebugHelper.log("Error loading user allergies: $e");
    }
  }

  void _applyFilters(Map<String, dynamic> filterResults) {
    try {
      setState(() {
        _maxPrice = (filterResults['maxPrice'] as double?) ?? 100.0;
        _minRating = (filterResults['minRating'] as double?) ?? 0.0;
        _maxDistance = (filterResults['maxDistance'] as double?) ?? 10.0;
      });
    } catch (e) {
      DebugHelper.log('Error applying filters: $e');
      setState(() {
        _maxPrice = 100.0;
        _minRating = 0.0;
        _maxDistance = 10.0;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedFilter = 'all';
      _maxPrice = 100.0;
      _minRating = 0.0;
      _maxDistance = 10.0;
    });
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty || _selectedFilter != 'all' || 
           _maxPrice < 100.0 || _minRating > 0.0 || _maxDistance < 10.0;
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: DishesScreenSearchBar(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              onSubmitted: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _hasActiveFilters ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: IconButton(
              icon: Icon(Icons.filter_list_rounded, color: _hasActiveFilters ? Colors.blue : Colors.grey.shade600),
              onPressed: () async {
                try {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FiltersScreen(
                        currentMaxPrice: _maxPrice,
                        currentMinRating: _minRating,
                        currentMaxDistance: _maxDistance,
                      ),
                    ),
                  );
                  if (result != null && mounted) _applyFilters(result);
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

  Widget _buildLocationStatus() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (_locationService.isLoading) {
      statusColor = Colors.blue;
      statusIcon = Icons.location_searching_rounded;
      statusText = 'getting_location'.tr();
    } else if (_locationService.locationError.isNotEmpty) {
      statusColor = Colors.orange;
      statusIcon = Icons.location_off_rounded;
      statusText = _locationService.locationError;
    } else if (_locationService.hasLocation) {
      statusColor = Colors.green;
      statusIcon = Icons.location_on_rounded;
      statusText = 'location_available'.tr();
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w500))),
          if (_locationService.locationError.isNotEmpty)
            TextButton(
              onPressed: _locationService.refreshLocation,
              child: Text('retry'.tr(), style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
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
          Expanded(child: Text('filters_active'.tr(), style: TextStyle(color: Colors.blue.shade700, fontSize: 14, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: _resetFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('clear_all'.tr(), style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishesStream() {
    return StreamBuilder<List<Dish>>(
      stream: _dishService.getAllDishes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
        if (snapshot.hasError) {
          DebugHelper.log('Dishes stream error: ${snapshot.error}');
          return _buildErrorState('error_loading_dishes'.tr());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

        try {
          List<Dish> dishesWithDistance = _calculateDishDistances(snapshot.data!);
          List<Dish> filteredDishes = _filtrationService.filterDishes(
            dishes: dishesWithDistance,
            userAllergies: _userAllergies,
            searchQuery: _searchQuery,
            maxPrice: _maxPrice,
            minRating: _minRating,
            selectedCategory: _selectedFilter,
          );

          filteredDishes = _filtrationService.sortByDistance(filteredDishes);
          return _buildDishesList(filteredDishes);
        } catch (e) {
          DebugHelper.log('Error processing dishes: $e');
          return _buildErrorState('error_processing_dishes'.tr());
        }
      },
    );
  }

  List<Dish> _calculateDishDistances(List<Dish> dishes) {
    if (!_locationService.hasLocation) return dishes;

    return dishes.map((dish) {
      try {
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
      } catch (e) {
        DebugHelper.log('Error calculating distance for dish ${dish.id}: $e');
        return dish;
      }
    }).toList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
          ),
          const SizedBox(height: 20),
          Text('loading_dishes'.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
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
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.restaurant_menu_rounded, size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            Text('no_dishes_available'.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 20),
              Text('no_matching_dishes'.tr(), style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
              if (_userAllergies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('some_dishes_filtered_due_to_allergies'.tr(), style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w400), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('reset_filters'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dishes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => DishCard(
        dish: dishes[index],
        onCardTap: () => _navigateToDishDetails(dishes[index]),
        onChefNameTap: () => _navigateToChefProfile(dishes[index].chefId),
      ),
    );
  }

  void _navigateToDishDetails(Dish dish) {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DishDetailsScreen(dish: dish)));
    } catch (e) {
      DebugHelper.log('Error navigating to dish details: $e');
    }
  }

  void _navigateToChefProfile(String chefId) {
    try {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChefProfileScreen(chefId: chefId)));
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _locationService.refreshLocation(),
            tooltip: 'refresh_location'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildLocationStatus(),
          CategoryFilterBar(
            filters: _filters,
            selectedFilter: _selectedFilter,
            onFilterSelected: (filter) => setState(() => _selectedFilter = filter),
          ),
          if (_hasActiveFilters) _buildActiveFiltersIndicator(),
          Expanded(child: _buildDishesStream()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationService.onStateChanged = null;
    super.dispose();
  }
}