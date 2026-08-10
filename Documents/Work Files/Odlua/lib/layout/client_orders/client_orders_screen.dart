// screens/client_orders_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/dishes/dishes_screen/widgets/dish_card.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filters.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_filters[index].tr()),
                selected: _selectedFilter == index,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = index;
                  });
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: mainColor.withOpacity(0.2),
                checkmarkColor: mainColor,
                labelStyle: TextStyle(
                  color: _selectedFilter == index
                      ? mainColor
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _selectedFilter == index
                        ? mainColor
                        : Colors.grey.shade300,
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
      availabilityType: dishData['availabilityType'] ?? 'sell',
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
    final totalPrice = orderData['totalPrice'] ?? 0.0;
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
          totalPrice: totalPrice,
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
                      .withOpacity(0.1),
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
              _buildDetailRow('unit_price'.tr(),
                  '${safeOrderData['currency'] ?? 'EUR'} ${(safeOrderData['unitPrice'] ?? 0).toStringAsFixed(2)}'),
              _buildDetailRow('total_price'.tr(),
                  '${safeOrderData['currency'] ?? 'EUR'} ${(safeOrderData['totalPrice'] ?? 0).toStringAsFixed(2)}'),
              if (safeOrderData['createdAt'] != null)
                _buildDetailRow('order_date'.tr(),
                    '${DateFormat('MMM dd, yyyy').format(_toDateTime(safeOrderData['createdAt']))} at ${DateFormat('HH:mm').format(_toDateTime(safeOrderData['createdAt']))}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            'no_orders_found'.tr(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'orders_will_appear_here'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('my_orders'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          const SizedBox(height: 8),
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
}

class OrderInfo {
  final String orderId;
  final String orderStatus;
  final int quantity;
  final double totalPrice;
  final DateTime? orderDate;

  const OrderInfo({
    required this.orderId,
    required this.orderStatus,
    required this.quantity,
    required this.totalPrice,
    this.orderDate,
  });
}
