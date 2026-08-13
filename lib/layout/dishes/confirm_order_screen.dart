// ─────────────────────────────────────────
// Screen: ConfirmOrderScreen
// Description: Final confirmation before order is placed. Shows
//              dish details, quantity, total, and delivery/pickup info.
// Contains: Order summary card, confirm button, Firestore order write
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/layout/orders/order_confirmation_screen.dart';

class ConfirmOrderScreen extends StatefulWidget {
  final Dish dish;
  final int quantity;

  const ConfirmOrderScreen({
    super.key,
    required this.dish,
    required this.quantity,
  });

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isProcessing = false;

  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentStock();
  }

  Future<void> _loadCurrentStock() async {
    try {
      final latestDishDoc =
          await _firestore.collection('dishes').doc(widget.dish.id).get();
      if (latestDishDoc.exists) {
        final latestDishData = latestDishDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentStock = (latestDishData['stock'] ??
                  latestDishData['quantityAvailable'] ??
                  0)
              .toInt();
        });
      }
    } catch (e, stackTrace) {
      DebugHelper.log('Error loading current stock: $e');
      DebugHelper.log('Stack trace: $stackTrace');
      // Fallback to dish's stock if fetch fails
      if (mounted) {
        setState(() {
          _currentStock = widget.dish.stock;
        });
      }
    }
  }

  /// Safely convert dynamic value to int
  int _safeInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<void> _createOrder() async {
    if (_isProcessing) return;

    // Validate quantity before processing
    if (widget.quantity <= 0) {
      _showErrorSnackBar('Invalid quantity');
      return;
    }

    // Validate dish ID
    if (widget.dish.id.isEmpty) {
      _showErrorSnackBar('Invalid dish');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('confirm_order.authentication_required'.tr());
        setState(() => _isProcessing = false);
        return;
      }

      // Fetch latest dish data to show accurate stock
      final latestDishDoc =
          await _firestore.collection('dishes').doc(widget.dish.id).get();
      if (!latestDishDoc.exists) {
        _showErrorSnackBar('confirm_order.dish_no_longer_available'.tr());
        setState(() => _isProcessing = false);
        return;
      }

      final latestDishData = latestDishDoc.data() as Map<String, dynamic>;

      // Safely extract stock with fallback chain
      final currentAvailableStock = _safeInt(latestDishData['stock']) > 0
          ? _safeInt(latestDishData['stock'])
          : _safeInt(latestDishData['availableStock']) > 0
              ? _safeInt(latestDishData['availableStock'])
              : _safeInt(latestDishData['quantityAvailable']);

      // Update UI with latest stock
      setState(() {
        _currentStock = currentAvailableStock;
      });

      // Validate stock
      if (currentAvailableStock < widget.quantity) {
        _showErrorSnackBar('confirm_order.only_x_available'
            .tr(args: [currentAvailableStock.toString()]));
        setState(() => _isProcessing = false);
        return;
      }

      // Validate quantity doesn't exceed reasonable limit
      if (widget.quantity > 100) {
        _showErrorSnackBar('Maximum order quantity is 100');
        setState(() => _isProcessing = false);
        return;
      }

      // Create order directly in Firestore
      final orderId = _firestore.collection('orders').doc().id;

      // Fetch consumer phone from their profile
      String consumerPhone = user.phoneNumber ?? '';
      if (consumerPhone.isEmpty) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 3));
          consumerPhone = userDoc.data()?['phone']?.toString().trim() ?? '';
        } catch (_) {
          // Non-critical — continue without phone
        }
      }

      // Safely extract dish image - try imageUrls first
      String? dishImage;
      if (widget.dish.imageUrls.isNotEmpty) {
        dishImage = widget.dish.imageUrls.first;
      }
      dishImage ??= widget.dish.mainImageUrl;

      final orderData = {
        'orderId': orderId,
        'dishId': widget.dish.id,
        'dishName': widget.dish.name,
        'dishImage': dishImage,
        'chefId': widget.dish.chefId,
        'chefName': widget.dish.chefName,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'Customer',
        'customerEmail': user.email ?? '',
        'consumerPhone': consumerPhone,
        'quantity': widget.quantity,
        'totalPrice': widget.dish.price * widget.quantity,
        'currency': widget.dish.currency,
        'status': 'pending',

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Create order
      await _firestore.collection('orders').doc(orderId).set(orderData);

      // Update dish stock
      await _firestore.collection('dishes').doc(widget.dish.id).update({
        'stock': FieldValue.increment(-widget.quantity),
        'availableStock': FieldValue.increment(-widget.quantity),
      });

      // CRITICAL: Re-fetch dish stock immediately to validate the update
      // This ensures stock actually decreased and catches any silent failures
      try {
        final postUpdateDishDoc =
            await _firestore.collection('dishes').doc(widget.dish.id).get();

        if (postUpdateDishDoc.exists) {
          final postUpdateData =
              postUpdateDishDoc.data() as Map<String, dynamic>;
          final newStock = _safeInt(postUpdateData['stock']) > 0
              ? _safeInt(postUpdateData['stock'])
              : _safeInt(postUpdateData['availableStock']) > 0
                  ? _safeInt(postUpdateData['availableStock'])
                  : _safeInt(postUpdateData['quantityAvailable']);

          // Validate that stock actually decreased
          if (newStock >= currentAvailableStock) {
            DebugHelper.log(
                '⚠️ Stock validation failed: expected decrease but got $newStock (was $currentAvailableStock)');
            // Don't throw - allow order to proceed but log for investigation
            // Could be a race condition or the dish uses a different stock field
          } else {
            DebugHelper.log(
                '✅ Stock successfully decreased: $currentAvailableStock -> $newStock');
          }

          // Update local stock display for UI consistency
          if (mounted) {
            setState(() {
              _currentStock = newStock;
            });
          }
        }
      } catch (e) {
        DebugHelper.log('⚠️ Failed to re-fetch stock after update: $e');
        // Don't fail the order - just log the issue
      }

      // NOTE: Chef notification is now handled automatically by Cloud Function
      // The sendNewOrderNotification trigger fires when the order document is created

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('confirm_order.order_placed_successfully'.tr()),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to Order Confirmation Screen with smooth transition
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  OrderConfirmationScreen(orderId: orderId),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    } on FirebaseException catch (e, stackTrace) {
      DebugHelper.log(
          'Order creation Firebase error: ${e.code} - ${e.message}');
      DebugHelper.log('Stack trace: $stackTrace');
      _showErrorSnackBar('confirm_order.failed_to_create_order'.tr());
    } catch (e, stackTrace) {
      DebugHelper.log('Order creation error: $e');
      DebugHelper.log('Stack trace: $stackTrace');
      _showErrorSnackBar('confirm_order.failed_to_create_order'.tr());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text('confirm_order.title'.tr()),
            centerTitle: true,
            backgroundColor: backgroundColor,
            foregroundColor: Colors.black87,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Summary Card
                _buildGlassCard(
                  child: Column(
                    children: [
                      // Dish Info
                      Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: NetworkImage(widget.dish.mainImageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.dish.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'confirm_order.available_count'
                                      .tr(args: [_currentStock.toString()]),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _currentStock > 0
                                        ? Colors.green.shade600
                                        : Colors.red.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Chef & Location Info
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'confirm_order.order_details'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        icon: Icons.person_rounded,
                        title: widget.dish.chefName,
                        subtitle: 'confirm_order.chef'.tr(),
                      ),
                      const SizedBox(height: 12),
                      // Security: Only show city, never full address
                      _buildInfoRow(
                        icon: Icons.location_on_rounded,
                        title: widget.dish.city ?? 'Unknown Location',
                        subtitle: widget.dish.distance != -1
                            ? 'confirm_order.distance_away'.tr(
                                args: [widget.dish.distance.toStringAsFixed(1)])
                            : 'pickup_location_shared_after_confirmation'.tr(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.timer_rounded,
                        title: 'confirm_order.minutes'.tr(
                            args: [widget.dish.preparationTimeMins.toString()]),
                        subtitle: 'confirm_order.preparation_time'.tr(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _createOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: mainColor.withValues(alpha: 0.3),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_cart_checkout_rounded,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Order Now',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        // Loading overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Processing your order...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: mainColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
