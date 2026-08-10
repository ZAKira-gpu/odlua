// ─────────────────────────────────────────
// Widget: DishCard
// Description: Reusable card showing dish image, title, price,
//              rating, and chef name. Used in grids and lists.
// Contains: CachedNetworkImage, star rating, favorite toggle
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/layout/client_orders/client_orders_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/location/services/location_obfuscation_service.dart';

class DishCard extends StatelessWidget {
  final Dish dish;
  final VoidCallback onCardTap;
  final VoidCallback onChefNameTap;
  final bool showOrderInfo;
  final OrderInfo? orderInfo;

  const DishCard({
    super.key,
    required this.dish,
    required this.onCardTap,
    required this.onChefNameTap,
    this.showOrderInfo = false,
    this.orderInfo,
  });

  String _getDistanceRange(double distance) {
    if (distance < 0) return '';
    return LocationObfuscationService.getApproximateDistanceRange(distance);
  }

  /// Returns the full address string: street + city + postal + country.
  /// Falls back to city + postalCode for dishes that predate exactLocation.
  String _getAddressText() {
    // Use approximate address from structured location (includes street, city, postal, country)
    if (dish.approximateAddress != null &&
        dish.approximateAddress!.isNotEmpty) {
      return dish.approximateAddress!;
    }
    // Legacy fallback: city + postalCode
    final parts = <String>[
      if (dish.city?.isNotEmpty == true) dish.city!,
      if (dish.postalCode?.isNotEmpty == true) dish.postalCode!,
    ];
    return parts.join(', ');
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'paid':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'declined':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'reserved':
        return 'pending'.tr();
      case 'confirmed':
        return 'confirmed'.tr();
      case 'paid':
        return 'paid'.tr();
      case 'completed':
        return 'completed'.tr();
      case 'declined':
        return 'declined'.tr();
      case 'expired':
        return 'expired'.tr();
      case 'cancelled':
        return 'cancelled'.tr();
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280, // Fixed height for consistent layout
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCardTap,
            splashColor: mainColor.withValues(alpha: 0.1),
            highlightColor: mainColor.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🖼️ IMAGE SECTION
                Expanded(
                  flex: 6, // Increased image ratio
                  child: Stack(
                    children: [
                      // Main Image
                      Positioned.fill(
                        child: Hero(
                          tag: 'dish-image-${dish.id}',
                          child: Image.network(
                            dish.mainImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                child: Icon(Iconsax.gallery,
                                    size: 32, color: Colors.grey.shade300),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade50,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: mainColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Gradient Overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.05),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // NEW Badge (Top Right) - only show for dishes less than 6 hours old
                      if (DateTime.now()
                              .difference(dish.createdAt.toDate())
                              .inHours <
                          6)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: mainColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: mainColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ),

                      // Status Badges (Top Left)
                      if (!dish.isAvailable ||
                          (showOrderInfo && orderInfo != null))
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!dish.isAvailable)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text('sold_out'.tr(),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                              if (showOrderInfo && orderInfo != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        _getStatusColor(orderInfo!.orderStatus),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getStatusColor(
                                                orderInfo!.orderStatus)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                      _getStatusText(orderInfo!.orderStatus),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 📝 CONTENT SECTION
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dish Name Row (Rating commented out)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                dish.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                  height: 1.2,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Rating section commented out
                            // const SizedBox(width: 8),
                            // Container(
                            //   padding: const EdgeInsets.symmetric(
                            //       horizontal: 8, vertical: 4),
                            //   decoration: BoxDecoration(
                            //     color: const Color(0xFFFFFBEB),
                            //     borderRadius: BorderRadius.circular(8),
                            //     border: Border.all(
                            //         color: const Color(0xFFFEF3C7)),
                            //   ),
                            //   child: Row(
                            //     mainAxisSize: MainAxisSize.min,
                            //     children: [
                            //       const Icon(Iconsax.star1,
                            //           size: 12, color: Color(0xFFF59E0B)),
                            //       const SizedBox(width: 4),
                            //       Text(
                            //         dish.rating.toStringAsFixed(1),
                            //         style: const TextStyle(
                            //             fontSize: 12,
                            //             fontWeight: FontWeight.w700,
                            //             color: Color(0xFFB45309)),
                            //       ),
                            //     ],
                            //   ),
                            // ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Chef Name
                        GestureDetector(
                          onTap: onChefNameTap,
                          child: Row(
                            children: [
                              Icon(Iconsax.user,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dish.chefName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Location Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Full address (street + city + postal + country)
                            if (!dish.hideAddressTitle &&
                                _getAddressText().isNotEmpty)
                              Expanded(
                                child: Text(
                                  _getAddressText(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            if (!dish.hideAddressTitle &&
                                _getAddressText().isNotEmpty &&
                                dish.hasDistance &&
                                dish.distance >= 0)
                              const SizedBox(width: 4),
                            // Distance badge
                            if (dish.hasDistance && dish.distance >= 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.grey.shade100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Iconsax.location,
                                        size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getDistanceRange(dish.distance),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
