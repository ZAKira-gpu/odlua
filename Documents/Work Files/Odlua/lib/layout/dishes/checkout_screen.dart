import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class CheckoutScreen extends StatefulWidget {
  final Dish dish;
  final int quantity;
  final double totalPrice;
  final String reservationId;

  const CheckoutScreen({
    super.key,
    required this.dish,
    required this.quantity,
    required this.totalPrice,
    required this.reservationId,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  String _selectedPayment = 'cash';
  bool _isProcessing = false;
  bool _validationInProgress = false;
  bool _reservationValid = true;
  String? _validationError;

  double get total => widget.totalPrice;

  @override
  void initState() {
    super.initState();
    _validateReservationStatus();
  }

  Future<void> _validateReservationStatus() async {
    setState(() => _validationInProgress = true);

    try {
      final reservationDoc = await _firestore
          .collection('reservations')
          .doc(widget.reservationId)
          .get();

      if (!reservationDoc.exists) {
        setState(() {
          _reservationValid = false;
          _validationError = 'checkout.reservation_not_found'.tr();
        });
        return;
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final status = reservationData['status'];

      if (status != 'accepted') {
        setState(() {
          _reservationValid = false;
          _validationError = 'checkout.reservation_not_accepted'.tr();
        });
        return;
      }

      final expiresAt = reservationData['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        setState(() {
          _reservationValid = false;
          _validationError = 'checkout.reservation_expired'.tr();
        });
        return;
      }

      setState(() => _reservationValid = true);
    } catch (e) {
      DebugHelper.log('Reservation validation error: $e');
      setState(() {
        _reservationValid = false;
        _validationError = 'checkout.validation_error'.tr();
      });
    } finally {
      setState(() => _validationInProgress = false);
    }
  }

  Future<void> _processPayment() async {
    if (!_reservationValid) {
      await _validateReservationStatus();
      if (!_reservationValid) return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('checkout.authentication_required'.tr());
        return;
      }

      // Get current data first
      final reservationDoc = await _firestore
          .collection('reservations')
          .doc(widget.reservationId)
          .get();
      final dishDoc =
          await _firestore.collection('dishes').doc(widget.dish.id).get();

      if (!reservationDoc.exists || reservationDoc['status'] != 'accepted') {
        _showErrorSnackBar('checkout.reservation_no_longer_valid'.tr());
        return;
      }

      if (!dishDoc.exists) {
        _showErrorSnackBar('checkout.dish_no_longer_available'.tr());
        return;
      }

      // Perform updates in batch
      final batch = _firestore.batch();

      // Update reservation
      batch.update(reservationDoc.reference, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'paymentMethod': _selectedPayment,
        'finalAmount': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create order
      final orderId = _firestore.collection('orders').doc().id;
      final orderRef = _firestore.collection('orders').doc(orderId);
      batch.set(orderRef, {
        'id': orderId,
        'reservationId': widget.reservationId,
        'customerId': user.uid,
        'customerName': user.displayName ?? 'checkout.customer'.tr(),
        'customerEmail': user.email,
        'chefId': widget.dish.chefId,
        'chefName': widget.dish.chefName,
        'dishId': widget.dish.id,
        'dishName': widget.dish.name,
        'dishImage': widget.dish.mainImageUrl,
        'quantity': widget.quantity,
        'unitPrice': widget.dish.price,
        'totalPrice': total,
        'currency': widget.dish.currency,
        'paymentMethod': _selectedPayment,
        'status': 'paid',
        'createdAt': FieldValue.serverTimestamp(),
        'paidAt': FieldValue.serverTimestamp(),
        'type': 'order',
      });

      // Update dish stock
      final currentStock =
          (dishDoc['stock'] ?? dishDoc['quantityAvailable'] ?? 0).toInt();
      batch.update(dishDoc.reference, {
        'stock': currentStock - widget.quantity,
        'quantityAvailable': currentStock - widget.quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();

      // Send notifications
      await _sendNotifications(user);

      _showSuccessSnackBar('checkout.payment_successful'.tr());

      // Navigate after success
      _navigateAfterSuccess();
    } catch (e) {
      DebugHelper.log('Payment processing error: $e');
      _showErrorSnackBar('checkout.payment_failed'.tr());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _navigateAfterSuccess() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // Pop all screens until we reach the home screen
      Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  Future<void> _sendNotifications(User user) async {
    try {
      await _notificationService.sendOrderNotification(
        recipientId: widget.dish.chefId,
        type: 'completed',
        orderId: widget.reservationId,
        dishName: widget.dish.name,
        customerName: user.displayName ?? 'checkout.customer'.tr(),
      );

      await _notificationService.sendOrderNotification(
        recipientId: user.uid,
        type: 'completed',
        orderId: widget.reservationId,
        dishName: widget.dish.name,
        chefName: widget.dish.chefName,
      );
    } catch (e) {
      DebugHelper.log('Error sending notifications: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool get _canProceedWithPayment {
    if (_validationInProgress) return false;
    if (!_reservationValid) return false;
    if (_isProcessing) return false;
    return true;
  }

  Widget _buildValidationStatus() {
    if (_validationInProgress) {
      return _buildGlassCard(
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: mainColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'checkout.validating_reservation'.tr(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (!_reservationValid) {
      return _buildGlassCard(
        child: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _validationError ?? 'checkout.reservation_invalid'.tr(),
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ),
            TextButton(
              onPressed: _validateReservationStatus,
              child: Text('checkout.retry_action'.tr()),
            ),
          ],
        ),
      );
    }

    return _buildGlassCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'checkout.reservation_valid_ready_to_pay'.tr(),
              style: TextStyle(color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('checkout.screen_title'.tr()),
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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Validation status
            _buildValidationStatus(),
            const SizedBox(height: 20),

            // Order Summary
            _buildSectionTitle('checkout.order_summary'.tr()),
            _buildGlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'checkout.by_chef'
                                  .tr(args: [widget.dish.chefName]),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.quantity} × ${widget.dish.currency}${widget.dish.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${widget.dish.currency}${(widget.dish.price * widget.quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: mainColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'checkout.preparation_time'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'checkout.minutes'.tr(
                            args: [widget.dish.preparationTimeMins.toString()]),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment Method
            _buildSectionTitle('checkout.payment_method'.tr()),
            _buildPaymentOption(
              icon: Icons.money_rounded,
              label: 'checkout.cash_on_pickup'.tr(),
              description: 'checkout.pay_when_pickup'.tr(),
              value: 'cash',
            ),

            const SizedBox(height: 24),

            // Price Breakdown
            _buildSectionTitle('checkout.price_breakdown'.tr()),
            _buildGlassCard(
              child: Column(
                children: [
                  _buildPriceRow('checkout.subtotal'.tr(), widget.totalPrice),
                  const Divider(height: 20),
                  _buildPriceRow('checkout.total_amount'.tr(), total,
                      isTotal: true),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceedWithPayment ? _processPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canProceedWithPayment ? mainColor : Colors.grey.shade400,
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
                          const Icon(Icons.payment_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'checkout.confirm_payment'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Security Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded,
                      color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'checkout.security_note'.tr(),
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String label,
    required String description,
    required String value,
  }) {
    final isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? mainColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? mainColor : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? mainColor : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isSelected ? mainColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isSelected
                          ? mainColor.withOpacity(0.8)
                          : Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? mainColor : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isTotal ? Colors.black87 : Colors.grey.shade600,
              fontSize: isTotal ? 16 : 15,
            ),
          ),
          Text(
            '${widget.dish.currency}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? mainColor : Colors.black87,
              fontSize: isTotal ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
