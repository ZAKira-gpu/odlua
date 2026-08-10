// screens/chef_reservation_management_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChefReservationManagementScreen extends StatefulWidget {
  const ChefReservationManagementScreen({super.key});

  @override
  State<ChefReservationManagementScreen> createState() =>
      _ChefReservationManagementScreenState();
}

class _ChefReservationManagementScreenState
    extends State<ChefReservationManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReservationService _reservationService = ReservationService();

  late TabController _tabController;
  List<DocumentSnapshot> _pendingReservations = [];
  List<DocumentSnapshot> _acceptedReservations = [];
  List<DocumentSnapshot> _completedReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReservations() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final reservationsSnapshot = await _firestore
          .collection('reservations')
          .where('chefId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _pendingReservations = reservationsSnapshot.docs
            .where((doc) => doc['status'] == 'pending')
            .toList();
        _acceptedReservations = reservationsSnapshot.docs
            .where((doc) => doc['status'] == 'accepted')
            .toList();
        _completedReservations = reservationsSnapshot.docs
            .where((doc) => ['completed', 'declined', 'expired', 'cancelled']
                .contains(doc['status']))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      DebugHelper.log('Error loading reservations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateReservationStatus({
    required String reservationId,
    required String status,
    String? reason,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _reservationService.updateReservationStatus(
        reservationId: reservationId,
        status: status,
        updatedBy: user.uid,
        reason: reason,
      );

      // Send notification to customer
      final reservationDoc =
          await _firestore.collection('reservations').doc(reservationId).get();
      if (reservationDoc.exists) {
        final reservationData = reservationDoc.data()!;
        await NotificationService().sendReservationNotification(
          recipientId: reservationData['customerId'],
          type: status,
          reservationId: reservationId,
          dishName: reservationData['dishName'],
          chefName: user.displayName ?? 'Chef',
        );
      }

      _loadReservations(); // Refresh the list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reservation_$status'.tr()),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      DebugHelper.log('Error updating reservation status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('update_failed'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeclineDialog(Map<String, dynamic> reservationData) {
    showDialog(
      context: context,
      builder: (context) => DeclineReservationDialog(
        onDecline: (reason) => _updateReservationStatus(
          reservationId: reservationData['id'],
          status: 'declined',
          reason: reason,
        ),
      ),
    );
  }

  void _openChatWithCustomer(Map<String, dynamic> reservationData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: 'reservation_${reservationData['id']}',
          recipientId: reservationData['customerId'],
          recipientName: reservationData['customerName'] ?? 'Customer',
          isOrderChat: true,
        ),
      ),
    );
  }

  Widget _buildReservationCard(DocumentSnapshot doc, bool isPending) {
    final data = doc.data() as Map<String, dynamic>;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final timeRemaining = expiresAt.difference(DateTime.now());
    final isExpired = timeRemaining.isNegative;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: data['dishImage'] != null
                      ? DecorationImage(
                          image: NetworkImage(data['dishImage']),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: mainColor.withOpacity(0.1),
                ),
                child: data['dishImage'] == null
                    ? Icon(Icons.restaurant, color: mainColor, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['dishName'] ?? 'Unknown Dish',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by'.tr(args: [data['customerName'] ?? 'Customer']),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${'quantity'.tr()}: x${data['quantity']} • ${'total'.tr()}: ${data['currency']} ${(data['totalPrice'] ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data['specialInstructions'] != null &&
              data['specialInstructions'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.message_rounded,
                      size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['specialInstructions'],
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending && !isExpired) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'time_remaining'.tr(),
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.orange.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openChatWithCustomer(data),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: Text('message'.tr()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isPending && !isExpired) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showDeclineDialog(data),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('decline'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateReservationStatus(
                      reservationId: data['id'],
                      status: 'accepted',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('accept'.tr()),
                  ),
                ),
              ] else if (isPending && isExpired) ...[
                Expanded(
                  child: Text(
                    'expired'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('reservation_management'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: mainColor,
          labelColor: mainColor,
          unselectedLabelColor: Colors.grey.shade600,
          tabs: [
            Tab(
              text: 'pending'.tr(),
              icon: Badge(
                isLabelVisible: _pendingReservations.isNotEmpty,
                label: Text(_pendingReservations.length.toString()),
                child: const Icon(Icons.pending_actions_rounded),
              ),
            ),
            Tab(text: 'accepted'.tr()),
            Tab(text: 'completed'.tr()),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Pending Tab
                _pendingReservations.isEmpty
                    ? _buildEmptyState('no_pending_reservations'.tr())
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _pendingReservations.length,
                          itemBuilder: (context, index) =>
                              _buildReservationCard(
                            _pendingReservations[index],
                            true,
                          ),
                        ),
                      ),

                // Accepted Tab
                _acceptedReservations.isEmpty
                    ? _buildEmptyState('no_accepted_reservations'.tr())
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _acceptedReservations.length,
                          itemBuilder: (context, index) =>
                              _buildReservationCard(
                            _acceptedReservations[index],
                            false,
                          ),
                        ),
                      ),

                // Completed Tab
                _completedReservations.isEmpty
                    ? _buildEmptyState('no_completed_reservations'.tr())
                    : RefreshIndicator(
                        onRefresh: _loadReservations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _completedReservations.length,
                          itemBuilder: (context, index) =>
                              _buildReservationCard(
                            _completedReservations[index],
                            false,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }
}

class DeclineReservationDialog extends StatefulWidget {
  final Function(String) onDecline;

  const DeclineReservationDialog({super.key, required this.onDecline});

  @override
  State<DeclineReservationDialog> createState() =>
      _DeclineReservationDialogState();
}

class _DeclineReservationDialogState extends State<DeclineReservationDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String _selectedReason = '';

  final List<String> _commonReasons = [
    'out_of_stock',
    'not_available_today',
    'kitchen_closed',
    'other_reason',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('decline_reservation'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('select_reason'.tr()),
          const SizedBox(height: 12),
          ..._commonReasons.map((reason) => RadioListTile<String>(
                value: reason,
                groupValue: _selectedReason,
                title: Text(reason.tr()),
                onChanged: (value) => setState(() {
                  _selectedReason = value!;
                  if (reason != 'other_reason') {
                    _reasonController.text = reason.tr();
                  } else {
                    _reasonController.clear();
                  }
                }),
              )),
          if (_selectedReason == 'other_reason') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'enter_reason'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: _selectedReason.isEmpty
              ? null
              : () {
                  widget.onDecline(_reasonController.text.isEmpty
                      ? _selectedReason.tr()
                      : _reasonController.text);
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('decline'.tr()),
        ),
      ],
    );
  }
}
