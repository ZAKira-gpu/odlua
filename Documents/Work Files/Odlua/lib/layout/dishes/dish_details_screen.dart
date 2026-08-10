import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import '../../utils/theme/custom_themes/main_colors.dart' as AppColors;
import 'confirm_order_screen.dart';

class DishDetailsScreen extends StatefulWidget {
  final Dish dish;

  const DishDetailsScreen({super.key, required this.dish});

  @override
  State<DishDetailsScreen> createState() => _DishDetailsScreenState();
}

class _DishDetailsScreenState extends State<DishDetailsScreen> {
  int _quantity = 1;
  bool _isLoadingChef = false;
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  final DishService _dishService = DishService();
  Dish? _updatedDish;

  @override
  void initState() {
    super.initState();
    _loadChefData();
    _checkIfFavorite();
    _setupDishListener();

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Set up real-time listener for dish updates
  void _setupDishListener() {
    _dishService.getDishById(widget.dish.id).then((dish) {
      if (dish != null && mounted) {
        setState(() {
          _updatedDish = dish;
        });
      }
    });
  }

  /// Get the current dish data (updated or original)
  Dish get _currentDish => _updatedDish ?? widget.dish;

  Future<void> _loadChefData() async {
    setState(() => _isLoadingChef = true);
    try {
      final chefDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentDish.chefId)
          .get();

      if (chefDoc.exists) {
        setState(() => _isLoadingChef = false);
      } else {
        setState(() => _isLoadingChef = false);
      }
    } catch (e) {
      _showErrorSnackBar('dish_details.error_loading_chef'.tr());
      setState(() => _isLoadingChef = false);
    }
  }

  Future<void> _checkIfFavorite() async {
    // Implement favorite check logic from Firestore
    // For now, set to false
    setState(() => _isFavorite = false);
  }

  Future<void> _toggleFavorite() async {
    try {
      // Implement favorite toggle logic with Firestore
      setState(() => _isFavorite = !_isFavorite);

      _showSuccessSnackBar(_isFavorite
          ? 'dish_details.added_to_favorites'.tr()
          : 'dish_details.removed_from_favorites'.tr());
    } catch (e) {
      _showErrorSnackBar('dish_details.error_toggling_favorite'.tr());
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'dish_details.report_dish'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.mainColor,
          ),
        ),
        content: Text('dish_details.report_dish_description'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'dish_details.cancel'.tr(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('dish_details.dish_reported'.tr());
            },
            child: Text(
              'dish_details.report'.tr(),
              style: TextStyle(color: AppColors.mainColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps() async {
    try {
      if (!_currentDish.hasCoordinates) {
        _showErrorSnackBar('dish_details.location_not_available'.tr());
        return;
      }

      final lat = _currentDish.latitude;
      final lng = _currentDish.longitude;

      if (lat == null || lng == null) {
        _showErrorSnackBar('dish_details.location_not_available'.tr());
        return;
      }

      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showErrorSnackBar('dish_details.cannot_open_maps'.tr());
      }
    } catch (e) {
      _showErrorSnackBar('dish_details.error_opening_maps'.tr());
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  String _formatPrice(double price, String currency) {
    if (price == 0) return 'dish_details.free'.tr();
    return '€${price.toStringAsFixed(2)}';
  }

  String _getDistanceText(double? distance) {
    if (distance == null || distance == -1) return 'dish_details.unknown'.tr();
    if (distance < 0.1) return '${(distance * 1000).toStringAsFixed(0)} m';
    if (distance < 1) return '${(distance * 1000).toStringAsFixed(0)} m';
    return '${distance.toStringAsFixed(1)} km';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildDietaryOption(String label, bool value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            value ? AppColors.mainColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value ? AppColors.mainColor : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline_rounded,
            size: 18,
            color: value ? AppColors.mainColor : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            label.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: value ? AppColors.mainColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyChip(String allergy, bool containsAllergy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: containsAllergy
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: containsAllergy ? Colors.red : Colors.green,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            containsAllergy
                ? Icons.warning_rounded
                : Icons.check_circle_rounded,
            size: 18,
            color: containsAllergy ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 6),
          Text(
            allergy.tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: containsAllergy ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityChip() {
    final type = _currentDish.availabilityType;
    final icon = type == 'donate'
        ? Icons.favorite_rounded
        : type == 'exchange'
            ? Icons.swap_horiz_rounded
            : Icons.shopping_cart_rounded;
    final color = type == 'donate'
        ? Colors.green
        : type == 'exchange'
            ? Colors.orange
            : AppColors.mainColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            type.tr(),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final address = _currentDish.locationString;
    final hasCoordinates = _currentDish.hasCoordinates;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mainColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_rounded,
                    color: AppColors.mainColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'dish_details.location'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (address.isNotEmpty &&
              address != 'dish_details.unknown_location'.tr()) ...[
            Row(
              children: [
                Icon(Icons.place_rounded,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_currentDish.hasDistance) ...[
            Row(
              children: [
                Icon(Icons.zoom_out_map_rounded,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'dish_details.distance'
                      .tr(args: [_getDistanceText(_currentDish.distance)]),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (hasCoordinates)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.map_rounded, size: 20),
                label: Text('dish_details.open_in_maps'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  elevation: 2,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_rounded,
                      color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'dish_details.location_not_specified'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllergiesSection() {
    final allergies = _currentDish.allergies ?? {};

    final commonAllergies = {
      'gluten': 'dish_details.gluten'.tr(),
      'dairy': 'dish_details.dairy'.tr(),
      'nuts': 'dish_details.nuts'.tr(),
      'peanuts': 'dish_details.peanuts'.tr(),
      'soy': 'dish_details.soy'.tr(),
      'eggs': 'dish_details.eggs'.tr(),
      'fish': 'dish_details.fish'.tr(),
      'shellfish': 'dish_details.shellfish'.tr(),
    };

    final presentAllergies = allergies.entries
        .where((entry) => entry.value == true)
        .map((entry) => commonAllergies[entry.key] ?? entry.key)
        .toList();

    final safeAllergies = allergies.entries
        .where((entry) => entry.value == false)
        .map((entry) => commonAllergies[entry.key] ?? entry.key)
        .toList();

    if (allergies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_rounded,
                  color: Colors.blue.shade600, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'dish_details.allergy_info_not_provided'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: presentAllergies.isNotEmpty
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded,
                    color:
                        presentAllergies.isNotEmpty ? Colors.red : Colors.green,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                'dish_details.allergy_information'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (presentAllergies.isNotEmpty) ...[
            Text(
              'dish_details.contains'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presentAllergies
                  .map((allergy) => _buildAllergyChip(allergy, true))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (safeAllergies.isNotEmpty) ...[
            Text(
              'dish_details.allergy_free'.tr(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: safeAllergies
                  .map((allergy) => _buildAllergyChip(allergy, false))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _currentDish.price * _quantity;
    final ingredients = _currentDish.ingredients;
    final dietaryOptions = _currentDish.dietaryOptions ?? {};
    final deliveryAvailable = _currentDish.deliveryAvailable;
    final pickupAvailable = _currentDish.pickupAvailable;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Image Carousel with Dots Indicator
          _buildImageCarousel(),

          // Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Favorite and More Options Buttons
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isFavorite ? Colors.red : Colors.white,
                          size: 24,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 24),
                        onPressed: _showReportDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scroll to Top Button
          if (_showScrollToTop)
            Positioned(
              bottom: 120,
              right: 20,
              child: FloatingActionButton(
                onPressed: _scrollToTop,
                backgroundColor: AppColors.mainColor,
                foregroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.arrow_upward_rounded),
              ),
            ),

          // Details Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Dish title and chef
                            Text(
                              _currentDish.name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Chef name with navigation
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChefProfileScreen(
                                        chefId: _currentDish.chefId),
                                  ),
                                );
                              },
                              child: _isLoadingChef
                                  ? _buildChefShimmer()
                                  : Row(
                                      children: [
                                        Icon(Icons.person_rounded,
                                            size: 18,
                                            color: Colors.grey.shade600),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentDish.chefName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios_rounded,
                                            size: 14,
                                            color: Colors.grey.shade500),
                                      ],
                                    ),
                            ),

                            const SizedBox(height: 20),

                            // Price and availability
                            Row(
                              children: [
                                Text(
                                  _formatPrice(_currentDish.price,
                                      _currentDish.currency),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.mainColor,
                                  ),
                                ),
                                const Spacer(),
                                _buildAvailabilityChip(),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Rating, distance, and prep time
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildMetricItem(
                                    icon: Icons.star_rounded,
                                    value:
                                        _currentDish.rating.toStringAsFixed(1),
                                    label: 'dish_details.rating'.tr(),
                                    color: Colors.amber,
                                  ),
                                  if (_currentDish.hasDistance)
                                    _buildMetricItem(
                                      icon: Icons.location_on_rounded,
                                      value: _getDistanceText(
                                          _currentDish.distance),
                                      label: 'dish_details.distance'.tr(),
                                      color: Colors.redAccent,
                                    ),
                                  _buildMetricItem(
                                    icon: Icons.timer_rounded,
                                    value:
                                        '${_currentDish.preparationTimeMins}',
                                    label: 'dish_details.prep_time'.tr(),
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Allergy Information
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildAllergiesSection(),
                      ),
                    ),

                    // Location Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildLocationSection(),
                      ),
                    ),

                    // Description
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dish_details.description'.tr(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _currentDish.description.isNotEmpty
                                  ? _currentDish.description
                                  : 'dish_details.no_description_available'
                                      .tr(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ingredients
                    if (ingredients.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dish_details.ingredients'.tr(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: ingredients.map((ingredient) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.mainColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      ingredient,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.mainColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Dietary Options
                    if (dietaryOptions.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dish_details.dietary_options'.tr(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  if (dietaryOptions['vegan'] != null)
                                    _buildDietaryOption('dish_details.vegan',
                                        dietaryOptions['vegan'] ?? false),
                                  if (dietaryOptions['vegetarian'] != null)
                                    _buildDietaryOption(
                                        'dish_details.vegetarian',
                                        dietaryOptions['vegetarian'] ?? false),
                                  if (dietaryOptions['halal'] != null)
                                    _buildDietaryOption('dish_details.halal',
                                        dietaryOptions['halal'] ?? false),
                                  if (dietaryOptions['gluten_free'] != null)
                                    _buildDietaryOption(
                                        'dish_details.gluten_free',
                                        dietaryOptions['gluten_free'] ?? false),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Delivery & Pickup Options
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dish_details.delivery_options'.tr(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDeliveryOption(
                                    icon: Icons.delivery_dining_rounded,
                                    title: 'dish_details.delivery'.tr(),
                                    available: deliveryAvailable,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDeliveryOption(
                                    icon: Icons.store_rounded,
                                    title: 'dish_details.pickup'.tr(),
                                    available: pickupAvailable,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quantity selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'dish_details.quantity'.tr(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _buildQuantityButton(
                                        icon: Icons.remove_rounded,
                                        onPressed: () {
                                          if (_quantity > 1) {
                                            setState(() => _quantity--);
                                          }
                                        },
                                        enabled: _quantity > 1,
                                      ),
                                      const SizedBox(width: 20),
                                      Text(
                                        _quantity.toString(),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      _buildQuantityButton(
                                        icon: Icons.add_rounded,
                                        onPressed: () {
                                          if (_quantity <
                                              _currentDish.availableStock) {
                                            setState(() => _quantity++);
                                          } else {
                                            _showErrorSnackBar(
                                                'dish_details.maximum_quantity_reached'
                                                    .tr());
                                          }
                                        },
                                        enabled: _quantity <
                                            _currentDish.availableStock,
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'dish_details.total'.tr(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            _formatPrice(totalPrice,
                                                _currentDish.currency),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.mainColor,
                                              fontSize: 22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'dish_details.available_stock'.tr(args: [
                                      _currentDish.availableStock.toString()
                                    ]),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _currentDish.isAvailable
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom spacing for the sticky button
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              );
            },
          ),

          // Sticky bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'dish_details.total'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _formatPrice(totalPrice, _currentDish.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainColor,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _currentDish.isAvailable
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConfirmOrderScreen(
                                    dish: _currentDish,
                                    quantity: _quantity,
                                    totalPrice: totalPrice,
                                    currency: _currentDish.currency,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white, size: 22),
                      label: Text(
                        _currentDish.availabilityType == 'donate'
                            ? 'dish_details.request_donation'.tr()
                            : _currentDish.availabilityType == 'exchange'
                                ? 'dish_details.propose_exchange'.tr()
                                : 'dish_details.add_to_cart'.tr(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentDish.isAvailable
                            ? AppColors.mainColor
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (_currentDish.imageUrls.isEmpty) {
      return SizedBox(
        height: 400,
        width: double.infinity,
        child: Container(
          color: Colors.grey.shade100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fastfood_rounded,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'dish_details.no_image_available'.tr(),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentDish.imageUrls.length == 1) {
      return SizedBox(
        height: 400,
        width: double.infinity,
        child: Image.network(
          _currentDish.mainImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded,
                    size: 50, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'dish_details.failed_to_load_image'.tr(),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey.shade100,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 400,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, reason) {
              setState(() => _currentImageIndex = index);
            },
          ),
          items: _currentDish.imageUrls.map((url) {
            return Builder(
              builder: (BuildContext context) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded,
                              size: 50, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'dish_details.failed_to_load_image'.tr(),
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _currentDish.imageUrls.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentImageIndex == entry.key
                    ? AppColors.mainColor
                    : Colors.grey.withOpacity(0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChefShimmer() {
    return Container(
      width: 120,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOption({
    required IconData icon,
    required String title,
    required bool available,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: available
            ? AppColors.mainColor.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? AppColors.mainColor : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: available ? AppColors.mainColor : Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: available ? AppColors.mainColor : Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            available
                ? 'dish_details.available'.tr()
                : 'dish_details.not_available'.tr(),
            style: TextStyle(
              fontSize: 13,
              color: available ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool enabled,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.mainColor.withOpacity(0.1)
            : Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? AppColors.mainColor : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: IconButton(
        icon: Icon(icon,
            color: enabled ? AppColors.mainColor : Colors.grey, size: 20),
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
