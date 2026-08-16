// ─────────────────────────────────────────
// Screen: ChefOrderManagementScreen
// Description: Chef’s order queue with tabs for pending, in-progress,
//              and completed orders. Real-time Firestore stream.
// Contains: Order list, status tabs, order card, detail navigation
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/services/chat_service.dart';

class ChefOrderManagementScreen extends StatefulWidget {
  final bool showAppBar;

  const ChefOrderManagementScreen({super.key, this.showAppBar = true});

  @override
  State<ChefOrderManagementScreen> createState() =>
      _ChefOrderManagementScreenState();
}

class _ChefOrderManagementScreenState extends State<ChefOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  final List<String> _tabs = ['pending', 'preparing', 'ready', 'completed'];
  final Map<String, IconData> _tabIcons = {
    'pending': Icons.access_time_rounded,
    'preparing': Icons.restaurant_menu_rounded,
    'ready': Icons.local_shipping_rounded,
    'completed': Icons.check_circle_rounded,
  };

  final Map<String, Color> _tabColors = {
    'pending': Colors.orange,
    'preparing': Colors.blue,
    'ready': Colors.green,
    'completed': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getOrdersStream(String status) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('chefId', isEqualTo: user.uid)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
      DebugHelper.logError('Orders stream error: $error');
    });
  }

  // Helper to count active orders for header summary
  Stream<QuerySnapshot> _getActiveOrdersCountStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    // We can't do a complex OR query easily without composite indexes for every combination,
    // so we'll just fetch active ones or rely on client side filtering if volume is low.
    // For a dashboard summary, let's just show "Pending" count for now as it's most critical.
    return _firestore
        .collection('orders')
        .where('chefId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('chef_dashboard'.tr(),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            )
          : null,
      body: Column(
        children: [
          // Dashboard Header Summary
          _buildDashboardHeader(),

          // Custom Tab Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: mainColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                tabs: _tabs.map((tab) => Tab(text: tab.tr())).toList(),
              ),
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children:
                  _tabs.map((status) => _buildOrdersList(status)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getActiveOrdersCountStream(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        if (snapshot.hasData) {
          pendingCount = snapshot.data!.docs.length;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'overview'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildSummaryCard(
                    title: 'pending_orders'.tr(),
                    count: pendingCount.toString(),
                    icon: Icons.access_time_rounded,
                    color: Colors.orange,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    bool isFeature = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (isFeature)
                  Icon(Icons.lock_outline,
                      size: 14, color: color.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(status),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _buildErrorState(snapshot.error.toString());
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) return _buildEmptyState(status);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            return _buildOrderCard(orders[index].id, orderData, status);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
      String orderId, Map<String, dynamic> orderData, String status) {
    final statusColor = _tabColors[status]!;
    final dishName = orderData['dishName'] ?? 'Unknown Dish';
    final customerName = orderData['customerName'] ?? 'Customer';
    final quantity = orderData['quantity'] ?? 1;
    final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Color Strip
              Container(
                width: 6,
                color: statusColor,
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Order ID & Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              '#${orderId.substring(0, 6)}'.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (createdAt != null)
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimeAgo(createdAt),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dish Info
                      Text(
                        '${quantity}x $dishName',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Price removed
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(Icons.person_outline_rounded,
                              size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          if (status == 'pending') ...[
                            Expanded(
                              child: _buildActionButton(
                                'confirm_order'.tr(),
                                Icons.check_circle_outline,
                                Colors.green,
                                () => _updateOrderStatus(orderId, 'preparing'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconActionButton(
                              Icons.cancel_outlined,
                              Colors.red.shade50,
                              Colors.red,
                              () => _showCancellationBottomSheet(orderId, orderData),
                            ),
                          ] else if (status == 'preparing')
                            Expanded(
                                child: _buildActionButton(
                                    'mark_ready'.tr(),
                                    Icons.check_circle_outline,
                                    Colors.blue,
                                    () => _updateOrderStatus(orderId, 'ready')))
                          else if (status == 'ready')
                            Expanded(
                                child: _buildActionButton(
                                    'mark_delivered'.tr(),
                                    Icons.done_all,
                                    Colors.green,
                                    () => _updateOrderStatus(
                                        orderId, 'completed'))),
                          if (status != 'completed') ...[
                            const SizedBox(width: 12),
                            _buildIconActionButton(
                                Icons.chat_bubble_outline_rounded,
                                Colors.grey.shade100,
                                Colors.black87,
                                () => _messageCustomer(orderData)),
                          ],
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
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        shadowColor: color.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildIconActionButton(
      IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _tabColors[status]!.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_tabIcons[status], size: 48, color: _tabColors[status]),
          ),
          const SizedBox(height: 16),
          Text(
            'no_orders_status'.tr(args: [status.tr()]),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(child: Text('error_generic'.tr(args: [error])));
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'just_now'.tr();
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('order_updated'.tr()),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      DebugHelper.logError('Error updating order: $e');
    }
  }

  void _showCancellationBottomSheet(
      String orderId, Map<String, dynamic> orderData) {
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
                                    content:
                                        Text('order.cancel_reason_required'.tr()),
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
                                    content:
                                        Text('order.cancel_reason_required'.tr()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              Navigator.pop(context);
                              await _cancelOrder(orderId, orderData, finalReason);
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
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  Future<void> _cancelOrder(
      String orderId, Map<String, dynamic> orderData, String reason) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelledBy': 'chef',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Restore stock
      try {
        final dishId = orderData['dishId']?.toString();
        final quantity = (orderData['quantity'] as num?)?.toInt();
        if (dishId != null && quantity != null && quantity > 0) {
          await _firestore.collection('dishes').doc(dishId).update({
            'stock': FieldValue.increment(quantity),
            'availableStock': FieldValue.increment(quantity),
          });
        }
      } catch (e) {
        DebugHelper.log('Stock restore error: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('order_cancelled'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      DebugHelper.logError('Error cancelling order: $e');
    }
  }



  Future<void> _messageCustomer(Map<String, dynamic> orderData) async {
    final customerId = orderData['customerId'];
    final customerName = orderData['customerName'] ?? 'Customer';
    if (customerId != null) {
      ChatService.navigateToChat(
          context: context,
          recipientId: customerId,
          recipientName: customerName);
    }
  }
}
