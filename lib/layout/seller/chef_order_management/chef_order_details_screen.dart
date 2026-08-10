// ─────────────────────────────────────────
// Screen: ChefOrderDetailsScreen
// Description: Detailed view of a single order for the chef.
//              Shows items, buyer info, status, and action buttons
//              (accept, reject, mark ready, complete).
// Contains: Order detail card, status stepper, action buttons
// ─────────────────────────────────────────

// layout/chef_order_management/chef_order_details_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/layout/profile/consumer_profile_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';

class ChefOrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const ChefOrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<ChefOrderDetailScreen> createState() => _ChefOrderDetailScreenState();
}

class _ChefOrderDetailScreenState extends State<ChefOrderDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _updateOrderStatus(String newStatus, {String? reason}) async {
    setState(() => _isLoading = true);

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'chefActionAt': FieldValue.serverTimestamp(),
      };

      if (reason != null && reason.isNotEmpty) {
        updateData['cancellationReason'] = reason;
      }

      if (newStatus == 'cancelled') {
        updateData['cancelledBy'] = 'chef';
      }

      await _firestore
          .collection('orders')
          .doc(widget.orderId)
          .update(updateData);

      // Restore stock when cancelled by chef
      if (newStatus == 'cancelled' || newStatus == 'declined') {
        try {
          final dishId = widget.orderData['dishId']?.toString();
          final quantity = (widget.orderData['quantity'] as num?)?.toInt();
          if (dishId != null && quantity != null && quantity > 0) {
            await _firestore.collection('dishes').doc(dishId).update({
              'stock': FieldValue.increment(quantity),
              'availableStock': FieldValue.increment(quantity),
            });
          }
        } catch (e) {
          DebugHelper.log('Error restoring stock: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('order_$newStatus'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      DebugHelper.log('Update order error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('update_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCancellationBottomSheet() {
    String? selectedReason;
    final TextEditingController customReasonController =
        TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
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
                    'order.cancel_order'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'order.cancel_confirm'.tr(),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: 'order.cancel_reason_distance'.tr(),
                      groupValue: selectedReason,
                      onChanged: (v) => setSheetState(() {
                        selectedReason = v;
                        customReasonController.clear();
                      }),
                      activeColor: Colors.red,
                    ),
                    title: Text('order.cancel_reason_distance'.tr()),
                    onTap: () => setSheetState(() {
                      selectedReason = 'order.cancel_reason_distance'.tr();
                      customReasonController.clear();
                    }),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: 'other',
                      groupValue: selectedReason,
                      onChanged: (v) => setSheetState(() => selectedReason = v),
                      activeColor: Colors.red,
                    ),
                    title: Text('order.cancel_reason_other'.tr()),
                    onTap: () => setSheetState(() => selectedReason = 'other'),
                  ),
                  if (selectedReason == 'other') ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: customReasonController,
                      maxLength: 200,
                      maxLines: 3,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: 'order.cancel_reason_write'.tr(),
                        border: const OutlineInputBorder(),
                        counterText:
                            '${customReasonController.text.length}/200',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedReason == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('order.select_reason'.tr()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              final finalReason = selectedReason == 'other'
                                  ? customReasonController.text.trim()
                                  : selectedReason!;
                              if (selectedReason == 'other' &&
                                  finalReason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'order.cancel_reason_required'.tr()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              // _updateOrderStatus handles stock restore,
                              // snackbar and navigation
                              await _updateOrderStatus('cancelled',
                                  reason: finalReason);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('order.cancel_order'.tr()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel_action'.tr()),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'reserved':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'paid':
        return Colors.blue;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('order_details'.tr()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Order Status Card
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'current_status'.tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _getStatusColor(widget.orderData['status'])
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    _getStatusColor(widget.orderData['status']),
                              ),
                            ),
                            child: Text(
                              _getStatusText(widget.orderData['status']),
                              style: TextStyle(
                                color:
                                    _getStatusColor(widget.orderData['status']),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Order Information
                  _buildGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'order_information'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('dish_name'.tr(),
                              widget.orderData['dishName'] ?? ''),
                          _buildCustomerRow(
                            widget.orderData['customerName'] ?? '',
                            widget.orderData['customerId'] as String?,
                          ),
                          // Display consumer phone (with fallback for backward compatibility)
                          _buildInfoRow('phone'.tr(),
                              _getConsumerPhone(widget.orderData)),
                          _buildInfoRow('quantity'.tr(),
                              'x${(widget.orderData['quantity'] as num?)?.toInt() ?? 1}'),
                          // Price removed
                          if (widget.orderData['specialInstructions'] != null &&
                              widget.orderData['specialInstructions']
                                  .toString()
                                  .isNotEmpty)
                            _buildInfoRow(
                                'special_instructions'.tr(),
                                widget.orderData['specialInstructions']
                                    .toString()),
                          if (widget.orderData['expiresAt'] != null)
                            _buildInfoRow(
                              'expires_at'.tr(),
                              () {
                                try {
                                  final v = widget.orderData['expiresAt'];
                                  if (v is Timestamp)
                                    return v.toDate().toString();
                                  return v.toString();
                                } catch (_) {
                                  return '';
                                }
                              }(),
                            ),
                          // Show cancellation reason if order is cancelled
                          if (widget.orderData['status'] == 'cancelled') ...[
                            if (widget.orderData['cancellationReason'] !=
                                    null &&
                                widget.orderData['cancellationReason']
                                    .toString()
                                    .isNotEmpty)
                              _buildInfoRow(
                                  'order.cancel_reason'.tr(),
                                  widget.orderData['cancellationReason']
                                      .toString()),
                            if (widget.orderData['cancelledBy'] != null)
                              _buildInfoRow(
                                widget.orderData['cancelledBy'] == 'chef'
                                    ? 'order.cancelled_by_chef'.tr()
                                    : 'order.cancelled_by_consumer'.tr(),
                                widget.orderData['cancelledBy'].toString(),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Action Buttons for actionable orders
                  if (widget.orderData['status'] == 'reserved' ||
                      widget.orderData['status'] == 'pending' ||
                      widget.orderData['status'] == 'confirmed')
                    _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'manage_order'.tr(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (widget.orderData['status'] == 'reserved' ||
                                widget.orderData['status'] == 'pending') ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _updateOrderStatus('confirmed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text('confirm_order'.tr()),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _showCancellationBottomSheet,
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'cancel_order'.tr(),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Safe area padding at bottom
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 100,
                  ),
                ],
              ),
            ),
    );
  }

  String _getConsumerPhone(Map<String, dynamic> orderData) {
    // First try: new denormalized consumerPhone field
    if (orderData.containsKey('consumerPhone')) {
      final phone = orderData['consumerPhone']?.toString() ?? '';
      if (phone.isNotEmpty) {
        return phone;
      }
    }

    // Second try: legacy - fetch from users collection (for old reservations)
    // This is a fallback for backward compatibility
    try {
      final customerId = orderData['customerId']?.toString();
      if (customerId != null && customerId.isNotEmpty) {
        // We can't do async here, so return placeholder
        // The UI will show "Not provided" and we could optionally fetch in initState
        // but for simplicity we'll just show fallback message
      }
    } catch (e) {
      DebugHelper.log('Error getting consumer phone: $e');
    }

    // Fallback: show email or "Not provided"
    final email = orderData['customerEmail']?.toString() ?? '';
    if (email.isNotEmpty) {
      return '$email (no phone)';
    }

    return 'not_provided'.tr();
  }

  Widget _buildCustomerRow(String name, String? consumerId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'customer'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: consumerId != null && consumerId.isNotEmpty
                    ? GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConsumerProfileScreen(
                              consumerId: consumerId,
                              consumerName: name,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: mainColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: mainColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded,
                                size: 13, color: mainColor),
                          ],
                        ),
                      )
                    : Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        textAlign: TextAlign.end,
                      ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[500],
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}
