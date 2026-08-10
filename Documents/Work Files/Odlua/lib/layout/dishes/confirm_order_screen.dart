import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/layout/reservation/reservation_waiting_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ConfirmOrderScreen extends StatefulWidget {
  final Dish dish;
  final int quantity;
  final double totalPrice;
  final String currency;

  const ConfirmOrderScreen({
    super.key,
    required this.dish,
    required this.quantity,
    required this.totalPrice,
    required this.currency,
  });

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReservationService _reservationService = ReservationService();
  bool _isProcessing = false;
  final TextEditingController _specialInstructionsController =
      TextEditingController();
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
    } catch (e) {
      DebugHelper.log('Error loading current stock: $e');
    }
  }

  String _formatPrice(double price, String currency) {
    if (price == 0) return 'confirm_order.free'.tr();
    return '€${price.toStringAsFixed(2)}';
  }

  Future<void> _createReservation() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('confirm_order.authentication_required'.tr());
        return;
      }

      // Fetch latest dish data to show accurate stock
      final latestDishDoc =
          await _firestore.collection('dishes').doc(widget.dish.id).get();
      if (!latestDishDoc.exists) {
        _showErrorSnackBar('confirm_order.dish_no_longer_available'.tr());
        return;
      }

      final latestDishData = latestDishDoc.data() as Map<String, dynamic>;
      final currentAvailableStock =
          (latestDishData['stock'] ?? latestDishData['quantityAvailable'] ?? 0)
              .toInt();

      // Update UI with latest stock
      setState(() {
        _currentStock = currentAvailableStock;
      });

      // Validate stock
      if (currentAvailableStock < widget.quantity) {
        _showErrorSnackBar('confirm_order.only_x_available'
            .tr(args: [currentAvailableStock.toString()]));
        return;
      }

      final result = await _reservationService.createReservation(
        dishId: widget.dish.id,
        chefId: widget.dish.chefId,
        customerId: user.uid,
        quantity: widget.quantity,
        totalPrice: widget.totalPrice,
        currency: widget.currency,
        specialInstructions: _specialInstructionsController.text.trim(),
      );

      if (result['success'] == true && mounted) {
        final reservationId = result['reservationId'];
        final expiresAt = result['expiresAt'] as DateTime;

        // Send notification to chef
        await NotificationService().sendReservationNotification(
          recipientId: widget.dish.chefId,
          type: 'pending',
          reservationId: reservationId!,
          dishName: widget.dish.name,
          customerName: user.displayName ?? 'confirm_order.customer'.tr(),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReservationWaitingScreen(
              dish: widget.dish,
              quantity: widget.quantity,
              totalPrice: widget.totalPrice,
              currency: widget.currency,
              expiresAt: expiresAt,
              reservationId: reservationId,
            ),
          ),
        );
      } else {
        final error =
            result['error'] ?? 'confirm_order.reservation_failed'.tr();
        _showErrorSnackBar(error);
      }
    } catch (e) {
      DebugHelper.log('Reservation creation error: $e');
      _showErrorSnackBar('confirm_order.reservation_failed'.tr());
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('confirm_order.title'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                              '${widget.quantity} × ${_formatPrice(widget.dish.price, widget.currency)}',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
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

                  // Total Price
                  Container(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    'confirm_order.total'.tr(),
                    widget.totalPrice,
                    widget.currency,
                    isTotal: true,
                  ),
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
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    title: widget.dish.locationString,
                    subtitle: widget.dish.distance != -1
                        ? 'confirm_order.distance_away'
                            .tr(args: [widget.dish.distance.toStringAsFixed(1)])
                        : 'confirm_order.distance_unknown'.tr(),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.timer_rounded,
                    title: 'confirm_order.minutes'
                        .tr(args: [widget.dish.preparationTimeMins.toString()]),
                    subtitle: 'confirm_order.preparation_time'.tr(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Special Instructions
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'confirm_order.special_instructions'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'confirm_order.optional'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _specialInstructionsController,
                      decoration: InputDecoration(
                        hintText:
                            'confirm_order.enter_special_instructions_hint'
                                .tr(),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Reserve Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _createReservation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: mainColor.withOpacity(0.3),
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
                          const Icon(Icons.lock_clock_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'confirm_order.reserve_now'.tr(),
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPriceRow(String label, double amount, String currency,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? Colors.black87 : Colors.grey.shade600,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            _formatPrice(amount, currency),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? mainColor : Colors.black87,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
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
            color: mainColor.withOpacity(0.1),
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
