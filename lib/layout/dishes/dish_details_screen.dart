// ─────────────────────────────────────────
// Screen: DishDetailsScreen
// Description: Full dish page — image gallery, price, description,
//              chef info, rating, allergy tags, and order button.
// Contains: Image carousel, chef card, rating bar, add-to-order CTA
// ─────────────────────────────────────────

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:odlua/layout/dishes/confirm_order_screen.dart';
import 'package:odlua/layout/seller/seller_profile_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/services/moderation_service.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class DishDetailsScreen extends StatefulWidget {
  final Dish dish;

  const DishDetailsScreen({super.key, required this.dish});

  @override
  State<DishDetailsScreen> createState() => _DishDetailsScreenState();
}

class _DishDetailsScreenState extends State<DishDetailsScreen> {
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  bool _isOwner = false;
  Map<String, dynamic>? _chefData;
  bool _chefLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
    _checkFavoriteStatus();
    _loadChefData();
  }

  void _checkOwnership() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isOwner = uid != null && uid == widget.dish.chefId;
  }

  Future<void> _checkFavoriteStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final favs = List<String>.from(doc.data()?['favoriteDishIds'] ?? []);
      if (mounted) setState(() => _isFavorite = favs.contains(widget.dish.id));
    } catch (e) {
      DebugHelper.log('Error checking favorite: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      if (_isFavorite) {
        await ref.update({
          'favoriteDishIds': FieldValue.arrayRemove([widget.dish.id]),
        });
      } else {
        await ref.update({
          'favoriteDishIds': FieldValue.arrayUnion([widget.dish.id]),
        });
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'dish_details.added_to_favorites'.tr()
                : 'dish_details.removed_from_favorites'.tr(),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      DebugHelper.log('Error toggling favorite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dish_details.error_toggling_favorite'.tr())),
      );
    }
  }

  Future<void> _loadChefData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.dish.chefId)
          .get();
      if (mounted) {
        setState(() {
          _chefData = doc.data();
          _chefLoading = false;
        });
      }
    } catch (e) {
      DebugHelper.log('Error loading chef: $e');
      if (mounted) setState(() => _chefLoading = false);
    }
  }

  void _shareDish() {
    final dish = widget.dish;
    final text =
        '${dish.name} by ${dish.chefName} — ${dish.price > 0 ? '€${dish.price.toStringAsFixed(2)}' : 'dish_details.free'.tr()}';
    Share.share(text);
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDishSheet(
        dishId: widget.dish.id,
        chefId: widget.dish.chefId,
        onSuccess: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      ),
    );
  }

  void _openChefProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChefProfileScreen(chefId: widget.dish.chefId),
      ),
    );
  }

  Future<void> _openMaps() async {
    final dish = widget.dish;
    if (dish.latitude == null || dish.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('dish_details.location_not_available'.tr())),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${dish.latitude},${dish.longitude}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('dish_details.cannot_open_maps'.tr())),
          );
        }
      }
    } catch (e) {
      DebugHelper.log('Error opening maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('dish_details.error_opening_maps'.tr())),
        );
      }
    }
  }

  void _onOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmOrderScreen(
          dish: widget.dish,
          quantity: _quantity,
        ),
      ),
    );
  }

  String _availabilityLabel(String type) {
    switch (type.toLowerCase()) {
      case 'donate':
        return 'dish_details.request_donation'.tr();
      case 'exchange':
        return 'dish_details.propose_exchange'.tr();
      default:
        return 'dish_details.add_to_cart'.tr();
    }
  }

  // ───────────────────────────── BUILD ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dish = widget.dish;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildImageCarousel(dish)),
              SliverToBoxAdapter(child: _buildInfoSection(dish)),
              SliverToBoxAdapter(child: _buildChefSection()),
              SliverToBoxAdapter(child: _buildDescriptionSection(dish)),
              if (dish.ingredients.isNotEmpty)
                SliverToBoxAdapter(child: _buildIngredientsSection(dish)),
              if (dish.dietaryOptions != null &&
                  dish.dietaryOptions!.isNotEmpty)
                SliverToBoxAdapter(child: _buildDietarySection(dish)),
              SliverToBoxAdapter(child: _buildAllergenSection(dish)),
              SliverToBoxAdapter(child: _buildDeliverySection(dish)),
              if (dish.hasCoordinates)
                SliverToBoxAdapter(child: _buildLocationSection(dish)),
              // spacing for bottom bar
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // ── Back / actions overlay ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      _circleButton(
                        icon: _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isFavorite ? Colors.red : Colors.white,
                        iconColor: _isFavorite ? Colors.white : Colors.black87,
                        onTap: _toggleFavorite,
                      ),
                      const SizedBox(width: 8),
                      _circleButton(
                        icon: Iconsax.share,
                        onTap: _shareDish,
                      ),
                      if (!_isOwner) ...[
                        const SizedBox(width: 8),
                        _circleButton(
                          icon: Iconsax.flag,
                          onTap: _showReportSheet,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── Bottom CTA ──
          if (!_isOwner)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(dish),
            ),
        ],
      ),
    );
  }

  // ───────────────────── Image carousel ─────────────────────

  Widget _buildImageCarousel(Dish dish) {
    if (dish.imageUrls.isEmpty) {
      return Container(
        height: 320,
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.image, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'dish_details.no_image_available'.tr(),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        CarouselSlider.builder(
          itemCount: dish.imageUrls.length,
          options: CarouselOptions(
            height: 320,
            viewportFraction: 1,
            enableInfiniteScroll: dish.imageUrls.length > 1,
            onPageChanged: (i, _) => setState(() => _currentImageIndex = i),
          ),
          itemBuilder: (_, index, __) => CachedNetworkImage(
            imageUrl: dish.imageUrls[index],
            width: double.infinity,
            height: 320,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Icon(Iconsax.gallery_slash,
                    size: 40, color: Colors.grey.shade400),
              ),
            ),
          ),
        ),
        if (dish.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                dish.imageUrls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentImageIndex ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentImageIndex
                        ? mainColor
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────── Info (name, price, badges) ─────────────────────

  Widget _buildInfoSection(Dish dish) {
    final priceText = dish.price > 0
        ? '€${dish.price.toStringAsFixed(2)}'
        : 'dish_details.free'.tr();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            dish.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          // Price + availability badge
          Row(
            children: [
              Text(
                priceText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: mainColor,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dish.availabilityType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: mainColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating + prep time
          Row(
            children: [
              Icon(Iconsax.star1, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text(
                dish.rating.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                ' (${dish.ratingsCount})',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 16),
              Icon(Iconsax.clock, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '${dish.preparationTimeMins} min',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (dish.category.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Iconsax.category, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  dish.category,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
          const Divider(height: 28),
        ],
      ),
    );
  }

  // ───────────────────── Chef section ─────────────────────

  Widget _buildChefSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _chefLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: _openChefProfile,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _chefData?['profileImageUrl'] != null &&
                            (_chefData!['profileImageUrl'] as String).isNotEmpty
                        ? CachedNetworkImageProvider(
                            _chefData!['profileImageUrl'])
                        : null,
                    child: _chefData?['profileImageUrl'] == null ||
                            (_chefData!['profileImageUrl'] as String).isEmpty
                        ? Icon(Iconsax.personalcard,
                            color: Colors.grey.shade500)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dish.chefName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.dish.city != null)
                          Text(
                            widget.dish.city!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Iconsax.arrow_right_3,
                      size: 20, color: Colors.grey.shade400),
                ],
              ),
            ),
    );
  }

  // ───────────────────── Description ─────────────────────

  Widget _buildDescriptionSection(Dish dish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.description'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            dish.description.isNotEmpty
                ? dish.description
                : 'dish_details.no_description_available'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Ingredients ─────────────────────

  Widget _buildIngredientsSection(Dish dish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.ingredients'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dish.ingredients
                .map((ing) => Chip(
                      label: Text(ing, style: const TextStyle(fontSize: 13)),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Dietary options ─────────────────────

  Widget _buildDietarySection(Dish dish) {
    final options = dish.dietaryOptions!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.dietary_options'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.entries
                .where((e) => e.value == true)
                .map(
                  (e) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _dietaryLabel(e.key),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mainColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _dietaryLabel(String key) {
    switch (key.toLowerCase()) {
      case 'halal':
        return 'dish_details.halal'.tr();
      case 'vegan':
        return 'dish_details.vegan'.tr();
      case 'vegetarian':
        return 'dish_details.vegetarian'.tr();
      case 'glutenfree':
      case 'gluten_free':
        return 'dish_details.gluten_free'.tr();
      default:
        return key;
    }
  }

  // ───────────────────── Allergens ─────────────────────

  Widget _buildAllergenSection(Dish dish) {
    final allergyMap = {
      'gluten': 'dish_details.gluten',
      'dairy': 'dish_details.dairy',
      'nuts': 'dish_details.nuts',
      'peanuts': 'dish_details.peanuts',
      'soy': 'dish_details.soy',
      'eggs': 'dish_details.eggs',
      'fish': 'dish_details.fish',
      'shellfish': 'dish_details.shellfish',
    };

    final active = dish.allergies?.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.allergy_information'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (dish.allergies == null || dish.allergies!.isEmpty)
            Text(
              'dish_details.allergy_info_not_provided'.tr(),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            )
          else if (active.isEmpty)
            Row(
              children: [
                Icon(Iconsax.shield_tick, size: 20, color: mainColor),
                const SizedBox(width: 8),
                Text(
                  'dish_details.allergy_free'.tr(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: mainColor),
                ),
              ],
            )
          else ...[
            Text(
              'dish_details.contains'.tr(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active.map((key) {
                final label = (allergyMap[key.toLowerCase()] ?? key).tr();
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────── Delivery options ─────────────────────

  Widget _buildDeliverySection(Dish dish) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.delivery_options'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _deliveryChip(
                icon: Iconsax.truck,
                label: 'dish_details.delivery'.tr(),
                active: dish.deliveryAvailable,
              ),
              const SizedBox(width: 12),
              _deliveryChip(
                icon: Iconsax.shop,
                label: 'dish_details.pickup'.tr(),
                active: dish.pickupAvailable,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deliveryChip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            active ? mainColor.withValues(alpha: 0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              active ? mainColor.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 18, color: active ? mainColor : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? mainColor : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── Location ─────────────────────

  Widget _buildLocationSection(Dish dish) {
    final locationLabel = dish.city ?? 'dish_details.unknown_location'.tr();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dish_details.location'.tr(),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _openMaps,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.location, size: 22, color: mainColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (dish.hasDistance && dish.distance >= 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'dish_details.distance'.tr(args: [
                                '${dish.distance.toStringAsFixed(1)} km'
                              ]),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'dish_details.open_in_maps'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: mainColor,
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

  // ───────────────────── Bottom bar ─────────────────────

  Widget _buildBottomBar(Dish dish) {
    final maxQty = dish.availableStock;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewPadding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity selector (only for sell type)
          if (dish.availabilityType.toLowerCase() == 'sell') ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _qtyButton(Iconsax.minus, () {
                    if (_quantity > 1) setState(() => _quantity--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _qtyButton(Iconsax.add, () {
                    if (_quantity < maxQty) {
                      setState(() => _quantity++);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'dish_details.maximum_quantity_reached'.tr())),
                      );
                    }
                  }),
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],
          // CTA button
          Expanded(
            child: ElevatedButton(
              onPressed: dish.isAvailable && !_isOwner ? _onOrder : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isOwner
                    ? 'dish_details.own_dish'.tr()
                    : _availabilityLabel(dish.availabilityType),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = Colors.black87,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}

class _ReportDishSheet extends StatefulWidget {
  final String dishId;
  final String chefId;
  final void Function(String) onSuccess;
  final void Function(String) onError;

  const _ReportDishSheet({
    required this.dishId,
    required this.chefId,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ReportDishSheet> createState() => _ReportDishSheetState();
}

class _ReportDishSheetState extends State<_ReportDishSheet> {
  bool _loading = false;
  bool _chefBlocked = false;

  Future<void> _report(String reason) async {
    setState(() => _loading = true);
    try {
      await ModerationService.instance.reportDish(
        dishId: widget.dishId,
        chefId: widget.chefId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('dish_details.dish_reported'.tr());
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onError('moderation.report_failed'.tr());
    }
  }

  Future<void> _block() async {
    setState(() => _loading = true);
    try {
      await ModerationService.instance.blockUser(widget.chefId);
      setState(() => _chefBlocked = true);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess('user_blocked'.tr());
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onError('failed_to_block_user'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      ('moderation.reason_inappropriate', Iconsax.warning_2),
      ('moderation.reason_spam', Iconsax.message_remove),
      ('moderation.reason_wrong_info', Iconsax.info_circle),
      ('moderation.reason_offensive', Iconsax.dislike),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                const SizedBox(height: 20),
                Text(
                  'dish_details.report_dish'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'dish_details.report_dish_description'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ...reasons.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(r.$2, color: mainColor, size: 22),
                      title:
                          Text(r.$1.tr(), style: const TextStyle(fontSize: 15)),
                      onTap: () => _report(r.$1),
                    )),
                const Divider(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Iconsax.user_remove,
                      color: Colors.red, size: 22),
                  title: Text(
                    'block_user'.tr(),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: _chefBlocked ? null : _block,
                ),
                ],
              ),
            ),
    );
  }
}
