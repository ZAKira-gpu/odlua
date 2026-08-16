// ─────────────────────────────────────────
// Screen: ClientOrdersScreen
// Description: Shows the buyer’s order history with status tabs
//              (active / completed / cancelled). Real-time Firestore.
// Contains: Order list, status chips, order detail navigation
// ─────────────────────────────────────────

// screens/client_orders_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/dishes/dishes_screen/widgets/dish_card.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/services/chat_service.dart';
import '../../utils/theme/custom_themes/main_colors.dart';
import 'package:iconsax/iconsax.dart';

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});

  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedFilter = 0;
  final List<String> _filters = [
    'all',
    'pending',
    'confirmed',
    'completed',
    'cancelled'
  ];

  // Helper method to safely convert dynamic maps to Map<String, dynamic>
  Map<String, dynamic> _convertToStringKeyMap(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    if (data is Map<dynamic, dynamic>) return Map<String, dynamic>.from(data);
    return {};
  }

  // Helper method to safely convert any date type to DateTime
  DateTime _toDateTime(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is Timestamp) return date.toDate();
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  // Helper method to safely convert any date type to Timestamp
  Timestamp _toTimestamp(dynamic date) {
    if (date == null) return Timestamp.now();
    if (date is Timestamp) return date;
    if (date is DateTime) return Timestamp.fromDate(date);
    if (date is String) {
      try {
        return Timestamp.fromDate(DateTime.parse(date));
      } catch (e) {
        return Timestamp.now();
      }
    }
    return Timestamp.now();
  }

  Stream<QuerySnapshot> _getClientOrders() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      DebugHelper.log('Client orders stream error: $error');
    });
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMarginLarge),
        child: Row(
          children: List.generate(_filters.length, (index) {
            final isSelected = _selectedFilter == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = index),
              child: Container(
                margin: const EdgeInsets.only(right: AppSpacing.s8),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? mainColor : Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                  border: Border.all(
                    color: isSelected ? mainColor : Colors.grey.shade200,
                  ),
                  boxShadow: isSelected ? AppSpacing.softShadow : null,
                ),
                child: Text(
                  _filters[index].tr(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Dish _createDishFromOrderData(
      Map<String, dynamic> orderData, Map<String, dynamic> dishData) {
    return Dish(
      id: orderData['dishId'] ?? '',
      name: dishData['name'] ?? orderData['dishName'] ?? 'Unknown Dish'.tr(),
      description: dishData['description'] ?? '',
      price: (dishData['price'] ?? orderData['unitPrice'] ?? 0).toDouble(),
      currency: dishData['currency'] ?? orderData['currency'] ?? 'EUR',
      chefId: orderData['chefId'] ?? '',
      chefName:
          dishData['chefName'] ?? orderData['chefName'] ?? 'Unknown Chef'.tr(),
      stock: dishData['stock'] ?? 0,
      preparationTimeMins: dishData['preparationTimeMins'] ?? 30,
      imageUrls: List<String>.from(dishData['imageURLs'] ?? []),
      category: dishData['category'] ?? 'general',
      rating: (dishData['ratingsAverage'] ?? 0).toDouble(),
      ratingsCount: dishData['ratingsCount'] ?? 0,
      createdAt: _toTimestamp(
          dishData['createdAt']), // Fixed: Use Timestamp instead of DateTime
      updatedAt: _toTimestamp(
          dishData['updatedAt']), // Fixed: Use Timestamp instead of DateTime
      ingredients: List<String>.from(dishData['ingredients'] ?? []),
      // Required fields for Dish model
      availableStock:
          (dishData['stock'] ?? 0) - (dishData['reservedCount'] ?? 0),
      tags: List<String>.from(dishData['tags'] ?? []),
      availabilityType: dishData['availabilityType'] ??
          'donate', // Changed from 'sell' - sell feature disabled
      dietaryOptions: _convertToStringKeyMap(dishData['dietaryOptions'] ?? {}),
      allergies: Map<String, bool>.from(dishData['allergies'] ?? {}),
      location: _convertToStringKeyMap(dishData['location'] ?? {}),
      deliveryAvailable: dishData['deliveryAvailable'] ?? false,
      pickupAvailable: dishData['pickupAvailable'] ?? false,
      isAvailable: dishData['isAvailable'] ?? true,
      isFeatured: dishData['isFeatured'] ?? false,
      isRecommended: dishData['isRecommended'] ?? false,
      distance: -1,
    );
  }

  Widget _buildOrderItem(DocumentSnapshot orderDoc) {
    // Safely convert the order data to Map<String, dynamic>
    final rawOrderData = orderDoc.data();
    final orderData = _convertToStringKeyMap(rawOrderData);

    // Safely extract and convert dishData
    final rawDishData = orderData['dishData'];
    final dishData = _convertToStringKeyMap(rawDishData);

    final dish = _createDishFromOrderData(orderData, dishData);

    final orderStatus = orderData['status'] ?? '';
    final quantity = orderData['quantity'] ?? 1;
    final createdAt = _toDateTime(orderData['createdAt']);
    final orderId = orderDoc.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DishCard(
        dish: dish,
        showOrderInfo: true,
        orderInfo: OrderInfo(
          orderId: orderId,
          orderStatus: orderStatus,
          quantity: quantity,
          orderDate: createdAt,
        ),
        onCardTap: () {
          _showOrderDetails(orderDoc, orderData, dish);
        },
        onChefNameTap: () {
          // Handle chef profile navigation if needed
        },
      ),
    );
  }

  void _showOrderDetails(
      DocumentSnapshot orderDoc, Map<String, dynamic> orderData, Dish dish) {
    // Convert order data safely for the modal
    final safeOrderData = _convertToStringKeyMap(orderData);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
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
                'order_details'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(safeOrderData['status'] ?? '')
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: _getStatusColor(safeOrderData['status'] ?? '')),
                ),
                child: Text(
                  _getStatusText(safeOrderData['status'] ?? ''),
                  style: TextStyle(
                    color: _getStatusColor(safeOrderData['status'] ?? ''),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('order_id'.tr(), orderDoc.id),
              _buildDetailRow(
                  'quantity'.tr(), 'x${safeOrderData['quantity'] ?? 1}'),

              if (safeOrderData['createdAt'] != null)
                _buildDetailRow('order_date'.tr(),
                    '${DateFormat('MMM dd, yyyy').format(_toDateTime(safeOrderData['createdAt']))} at ${DateFormat('HH:mm').format(_toDateTime(safeOrderData['createdAt']))}'),
              // Show cancellation reason if order is cancelled
              if (safeOrderData['status'] == 'cancelled') ...[
                if (safeOrderData['cancellationReason'] != null &&
                    safeOrderData['cancellationReason'].toString().isNotEmpty)
                  _buildDetailRow('order.cancel_reason'.tr(),
                      safeOrderData['cancellationReason'].toString()),
                if (safeOrderData['cancelledBy'] != null)
                  _buildDetailRow(
                    safeOrderData['cancelledBy'] == 'chef'
                        ? 'order.cancelled_by_chef'.tr()
                        : 'order.cancelled_by_consumer'.tr(),
                    safeOrderData['cancelledBy'].toString(),
                  ),
              ],
              const SizedBox(height: 20),
              // Show cancel button for pending, confirmed, or reserved orders
              if (safeOrderData['status'] == 'pending' ||
                  safeOrderData['status'] == 'confirmed' ||
                  safeOrderData['status'] == 'reserved')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancellationBottomSheet(
                          orderDoc.id, safeOrderData),
                      icon: const Icon(Iconsax.close_circle, size: 20),
                      label: Text('order.cancel_order'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _messageChef(
                            safeOrderData['chefId'] ?? '',
                            safeOrderData['chefName'] ?? 'Chef'.tr(),
                            orderDoc.id);
                      },
                      icon: const Icon(Icons.message_rounded, size: 20),
                      label: Text('message_chef'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mainColor,
                        side: BorderSide(color: mainColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('close'.tr()),
                    ),
                  ),
                ],
              ),
              // Safe area padding at bottom
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16,
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  Future<void> _messageChef(
      String chefId, String chefName, String orderId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (!mounted) return;

    final result = await ChatService.navigateToChat(
      context: context,
      recipientId: chefId,
      recipientName: chefName,
    );

    if (!result.success && mounted) {
      DebugHelper.logError('Error opening chat: ${result.error}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('failed_to_open_chat'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.document_copy,
                  size: 64, color: Colors.grey.shade300),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(
              'no_orders_found'.tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'orders_will_appear_here'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'my_orders'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          const SizedBox(height: AppSpacing.s4),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getClientOrders(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'error_loading_orders'.tr(),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                List<DocumentSnapshot> orders = snapshot.data!.docs;

                if (_selectedFilter > 0) {
                  final filterStatus = _filters[_selectedFilter];
                  orders = orders.where((order) {
                    final orderData = _convertToStringKeyMap(order.data());
                    final status = orderData['status'] ?? '';
                    return status == filterStatus;
                  }).toList();
                }

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt_off_rounded,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'no_orders_filter'.tr(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderItem(orders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCancellationBottomSheet(
      String orderId, Map<String, dynamic> orderData) {
    final TextEditingController _reasonController = TextEditingController();
    bool _isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
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
                  const SizedBox(height: 8),
                  Text(
                    'order.cancel_confirm'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'order.cancel_reason'.tr(),
                      hintText: 'order.cancel_reason_write'.tr(),
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final reason = _reasonController.text.trim();
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('order.cancel_reason_required'.tr()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setState(() => _isLoading = true);

                              try {
                                final updateData = <String, dynamic>{
                                  'status': 'cancelled',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  'cancelledBy': 'consumer',
                                  'cancellationReason': reason,
                                };

                                await _firestore
                                    .collection('orders')
                                    .doc(orderId)
                                    .update(updateData);

                                // Restore stock
                                try {
                                  final dishId =
                                      orderData['dishId']?.toString();
                                  final quantity = orderData['quantity'];
                                  if (dishId != null && quantity != null) {
                                    await _firestore
                                        .collection('dishes')
                                        .doc(dishId)
                                        .update({
                                      'stock': FieldValue.increment(quantity),
                                      'availableStock':
                                          FieldValue.increment(quantity),
                                    });
                                  }
                                } catch (e) {
                                  // Non-critical error
                                }

                                if (!context.mounted) return;
                                Navigator.pop(context); // Close bottom sheet

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('order.cancelled_success'.tr()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('order.cancel_failed'.tr()),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel_action'.tr()),
                    ),
                  ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OrderInfo {
  final String orderId;
  final String orderStatus;
  final int quantity;
  final DateTime? orderDate;

  const OrderInfo({
    required this.orderId,
    required this.orderStatus,
    required this.quantity,
    this.orderDate,
  });
}
