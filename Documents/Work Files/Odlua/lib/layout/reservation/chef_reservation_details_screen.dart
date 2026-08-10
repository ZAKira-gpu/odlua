// screens/chef_reservation_details_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';


class ChefReservationDetailsScreen extends StatefulWidget {
  final String reservationId;
  final Map<String, dynamic> reservationData;

  const ChefReservationDetailsScreen({
    super.key,
    required this.reservationId,
    required this.reservationData,
  });

  @override
  State<ChefReservationDetailsScreen> createState() => _ChefReservationDetailsScreenState();
}

class _ChefReservationDetailsScreenState extends State<ChefReservationDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ReservationService _reservationService = ReservationService(); // ADD THIS
  Map<String, dynamic>? _customerData;
  Map<String, dynamic>? _dishData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdditionalData();
  }

  Future<void> _loadAdditionalData() async {
    try {
      // Load customer data
      final customerId = widget.reservationData['customerId'];
      if (customerId != null) {
        final customerDoc = await _firestore.collection('users').doc(customerId).get();
        if (customerDoc.exists) {
          setState(() {
            _customerData = customerDoc.data();
          });
        }
      }

      // Load dish data
      final dishId = widget.reservationData['dishId'];
      if (dishId != null) {
        final dishDoc = await _firestore.collection('dishes').doc(dishId).get();
        if (dishDoc.exists) {
          setState(() {
            _dishData = dishDoc.data();
          });
        }
      }
    } catch (e) {
      DebugHelper.log('Error loading additional data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // CORRECTED METHOD WITH 2 PARAMETERS
  Future<void> _updateReservationStatus(String newStatus, {String? reason}) async {
    try {
      final success = await _reservationService.updateReservationStatus(
        reservationId: widget.reservationId, // ADD THIS PARAMETER
        status: newStatus,
        updatedBy: _auth.currentUser!.uid,
        reason: reason,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('reservation_$newStatus'.tr()),
            backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.orange,
          ),
        );
        
        // Navigate back after successful update
        Navigator.pop(context);
      }
    } catch (e) {
      DebugHelper.log('Update reservation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('update_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGlassCard({required Widget child}) {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildCustomerInfo() {
    if (_isLoading) {
      return _buildGlassCard(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_customerData == null) {
      return _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.person_off_rounded, size: 50, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'customer_info_unavailable'.tr(),
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final customerName = _customerData!['name'] ?? 'Unknown Customer';
    final customerEmail = _customerData!['email'] ?? 'No email';
    final joinDate = _customerData!['createdAt']?.toDate();

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded, color: mainColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customerEmail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (joinDate != null) 
              _buildInfoRow(
                Icons.calendar_today_rounded, 
                'member_since'.tr(), 
                DateFormat('MMM yyyy').format(joinDate)
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationDetails() {
    final reservationData = widget.reservationData;
    final expiresAt = reservationData['expiresAt']?.toDate();
    final timeRemaining = expiresAt?.difference(DateTime.now());
    final isExpired = timeRemaining != null && timeRemaining.isNegative;
    final status = reservationData['status'] ?? 'pending';
    final isPending = status == 'pending' && !isExpired;

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'reservation_details'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dish Info
            if (_dishData != null) 
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: mainColor.withOpacity(0.1),
                      image: _dishData!['imageURLs'] != null && 
                             (_dishData!['imageURLs'] as List).isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage((_dishData!['imageURLs'] as List).first),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _dishData!['imageURLs'] == null || 
                           (_dishData!['imageURLs'] as List).isEmpty
                        ? Icon(Icons.restaurant_rounded, color: mainColor, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dishData!['name'] ?? 'Unknown Dish',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'quantity'.tr()}: x${reservationData['quantity']}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: mainColor.withOpacity(0.1),
                    ),
                    child: Icon(Icons.restaurant_rounded, color: mainColor, size: 30),
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'quantity'.tr()}: x${reservationData['quantity']}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 20),
            
            // Price Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('unit_price'.tr(), 
                    '${reservationData['currency']} ${(reservationData['totalPrice']! / reservationData['quantity']).toStringAsFixed(2)}'),
                  _buildSummaryRow('quantity'.tr(), 'x${reservationData['quantity']}'),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'total_amount'.tr(),
                    '${reservationData['currency']} ${(reservationData['totalPrice'] ?? 0).toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            
            // Special Instructions
            if (reservationData['specialInstructions'] != null && 
                reservationData['specialInstructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.note_rounded, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'special_instructions'.tr(),
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reservationData['specialInstructions'].toString(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Time remaining for pending reservations
            if (isPending && timeRemaining != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'time_remaining'.tr(),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${timeRemaining.inMinutes}:${(timeRemaining.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isExpired) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_off_rounded, color: Colors.grey, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'reservation_expired'.tr(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey.shade600,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? mainColor : Colors.black,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.reservationData['expiresAt']?.toDate();
    final isExpired = expiresAt?.isBefore(DateTime.now()) ?? false;
    final status = widget.reservationData['status'] ?? 'pending';
    final isPending = status == 'pending' && !isExpired;

    return Scaffold(
      appBar: AppBar(
        title: Text('reservation_details'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildCustomerInfo(),
                  const SizedBox(height: 16),
                  _buildReservationDetails(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Action Buttons for pending reservations
          if (isPending)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showDeclineConfirmation(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('decline'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAcceptConfirmation(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('accept'.tr()),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAcceptConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_accept'.tr()),
        content: Text('confirm_accept_reservation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus('accepted'); // FIXED: Now passing correct parameters
            },
            style: TextButton.styleFrom(foregroundColor: mainColor),
            child: Text('accept'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDeclineConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('confirm_decline'.tr()),
        content: Text('confirm_decline_reservation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus('declined'); // FIXED: Now passing correct parameters
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('decline'.tr()),
          ),
        ],
      ),
    );
  }
}