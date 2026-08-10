// screens/chef_order_management_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/layout/reservation/chef_reservation_details_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChefOrderManagementScreen extends StatefulWidget {
  const ChefOrderManagementScreen({super.key});

  @override
  State<ChefOrderManagementScreen> createState() => _ChefOrderManagementScreenState();
}

class _ChefOrderManagementScreenState extends State<ChefOrderManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _selectedTab = 0;
  final List<String> _tabs = ['pending', 'accepted', 'completed', 'cancelled', 'all'];

  Stream<QuerySnapshot> _getReservationsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('reservations')
        .where('chefId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((error) {
      DebugHelper.log('Reservations stream error: $error');
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.green;
      case 'declined': return Colors.red;
      case 'expired': return Colors.grey;
      case 'cancelled': return Colors.grey;
      case 'completed': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'pending'.tr();
      case 'accepted': return 'accepted'.tr();
      case 'declined': return 'declined'.tr();
      case 'expired': return 'expired'.tr();
      case 'cancelled': return 'cancelled'.tr();
      case 'completed': return 'completed'.tr();
      default: return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReservationCard(DocumentSnapshot reservationDoc) {
    final reservationData = reservationDoc.data() as Map<String, dynamic>;
    final reservationId = reservationDoc.id;
    final expiresAt = reservationData['expiresAt']?.toDate();
    final timeRemaining = expiresAt?.difference(DateTime.now());
    final status = reservationData['status'] ?? 'pending';
    final isExpired = timeRemaining != null && timeRemaining.isNegative;
    final isPending = status == 'pending' && !isExpired;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChefReservationDetailsScreen(
                  reservationId: reservationId,
                  reservationData: reservationData,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with dish info and status
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.restaurant, color: mainColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reservationData['dishName'] ?? 'Unknown Dish',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${'by'.tr()} ${reservationData['customerName'] ?? 'Customer'}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Reservation details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailItem('quantity'.tr(), 'x${reservationData['quantity']}'),
                    _buildDetailItem('total'.tr(), 
                        '${reservationData['currency']} ${(reservationData['totalPrice'] ?? 0).toStringAsFixed(2)}'),
                    _buildDetailItem('created'.tr(), 
                        _formatTimeAgo(reservationData['createdAt']?.toDate())),
                  ],
                ),
                
                // Time remaining for pending reservations
                if (isPending && timeRemaining != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'remaining'.tr(),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Action buttons for pending reservations
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateReservationStatus(reservationId, 'declined'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('decline'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateReservationStatus(reservationId, 'accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mainColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('accept'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '--';
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'just_now'.tr();
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  Future<void> _updateReservationStatus(String reservationId, String newStatus) async {
    try {
      await _firestore.collection('reservations').doc(reservationId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'chef',
        if (newStatus == 'accepted') 'acceptedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'declined') 'declinedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('reservation_$newStatus'.tr()),
          backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      DebugHelper.log('Update reservation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('update_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: _selectedTab == index ? mainColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      _tabs[index].tr(),
                      style: TextStyle(
                        color: _selectedTab == index ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'no_reservations'.tr(),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'reservations_will_appear_here'.tr(),
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<DocumentSnapshot> _filterReservations(List<DocumentSnapshot> reservations) {
    switch (_selectedTab) {
      case 0: // pending
        return reservations.where((res) => 
          res['status'] == 'pending' && 
          (res['expiresAt']?.toDate().isAfter(DateTime.now()) ?? false)
        ).toList();
      case 1: // accepted
        return reservations.where((res) => res['status'] == 'accepted').toList();
      case 2: // completed
        return reservations.where((res) => res['status'] == 'completed').toList();
      case 3: // cancelled
        return reservations.where((res) => 
          res['status'] == 'declined' || 
          res['status'] == 'cancelled' || 
          res['status'] == 'expired'
        ).toList();
      case 4: // all
      default:
        return reservations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reservation_management'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReservationsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'error_loading_reservations'.tr(),
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

                List<DocumentSnapshot> reservations = snapshot.data!.docs;
                List<DocumentSnapshot> filteredReservations = _filterReservations(reservations);

                if (filteredReservations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_list, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'no_reservations_in_category'.tr(),
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
                  itemCount: filteredReservations.length,
                  itemBuilder: (context, index) {
                    return _buildReservationCard(filteredReservations[index]);
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