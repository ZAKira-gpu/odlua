// screens/reservation_waiting_screen.dart
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/layout/dishes/checkout_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ReservationWaitingScreen extends StatefulWidget {
  final Dish? dish;
  final int? quantity;
  final double? totalPrice;
  final String? currency;
  final DateTime? expiresAt;
  final String? reservationId;

  const ReservationWaitingScreen({
    super.key,
    this.dish,
    this.quantity,
    this.totalPrice,
    this.currency,
    this.expiresAt,
    this.reservationId,
  });

  factory ReservationWaitingScreen.empty() {
    return const ReservationWaitingScreen();
  }

  @override
  State<ReservationWaitingScreen> createState() => _ReservationWaitingScreenState();
}

class _ReservationWaitingScreenState extends State<ReservationWaitingScreen> 
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  Map<String, dynamic>? _reservationData;
  bool _reservationNotFound = false;
  bool _hasNotifiedAccepted = false;
  bool _hasNotifiedDeclined = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  StreamSubscription<DocumentSnapshot>? _reservationSubscription;
  Dish? _currentDish;
  int? _currentQuantity;
  double? _currentTotalPrice;
  String? _currentCurrency;
  DateTime? _currentExpiresAt;
  String? _currentReservationId;
  String _currentCollection = 'reservations';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _initializeWithData();
  }

  void _initializeWithData() {
    _currentDish = widget.dish;
    _currentQuantity = widget.quantity;
    _currentTotalPrice = widget.totalPrice;
    _currentCurrency = widget.currency;
    _currentExpiresAt = widget.expiresAt;
    _currentReservationId = widget.reservationId;

    if (_hasValidReservationData) {
      _animationController.repeat(reverse: true);
      _startCountdown();
      _loadReservation();
    } else {
      _findActiveReservation();
    }
  }

  bool get _hasValidReservationData {
    return _currentReservationId != null && _currentExpiresAt != null;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    _reservationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _findActiveReservation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Look in both collections to find active reservation
      final reservationsQuery = _firestore
          .collection('reservations')
          .where('customerId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final ordersQuery = _firestore
          .collection('orders')
          .where('customerId', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted', 'reserved'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      final [reservationsSnapshot, ordersSnapshot] = await Future.wait([reservationsQuery, ordersQuery]);

      DocumentSnapshot? activeReservation;
      String collectionName = 'reservations';

      if (reservationsSnapshot.docs.isNotEmpty) {
        activeReservation = reservationsSnapshot.docs.first;
        collectionName = 'reservations';
      } else if (ordersSnapshot.docs.isNotEmpty) {
        activeReservation = ordersSnapshot.docs.first;
        collectionName = 'orders';
      }

      if (activeReservation != null) {
        final reservationData = activeReservation.data() as Map<String, dynamic>;
        
        setState(() {
          _currentReservationId = activeReservation!.id;
          _reservationData = reservationData;
          _reservationNotFound = false;
          _currentCollection = collectionName;
          _currentExpiresAt = (reservationData['expiresAt'] as Timestamp).toDate();
          _currentQuantity = reservationData['quantity'] ?? 1;
          _currentTotalPrice = (reservationData['totalPrice'] ?? 0).toDouble();
          _currentCurrency = reservationData['currency'] ?? 'EUR';
        });

        await _loadDishData(reservationData['dishId']);
        
        if (_hasValidReservationData) {
          _animationController.repeat(reverse: true);
          _startCountdown();
          _loadReservation();
        }
      } else {
        setState(() {
          _reservationNotFound = true;
        });
      }
    } catch (e) {
      DebugHelper.log('Error finding active reservation: $e');
      setState(() {
        _reservationNotFound = true;
      });
    }
  }

  Future<void> _loadDishData(String? dishId) async {
    if (dishId == null) return;
    
    try {
      final dishDoc = await _firestore.collection('dishes').doc(dishId).get();
      if (dishDoc.exists) {
        setState(() {
          _currentDish = Dish.fromFirestore(dishDoc);
        });
      }
    } catch (e) {
      DebugHelper.log('Error loading dish data: $e');
    }
  }

  void _startCountdown() {
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (_currentExpiresAt == null) return;
    
    final now = DateTime.now();
    final difference = _currentExpiresAt!.difference(now);
    setState(() {
      _remainingTime = difference.isNegative ? Duration.zero : difference;
    });

    // Auto-expire reservation
    if (difference.isNegative && _reservationData?['status'] == 'pending') {
      _handleAutoExpire();
    }
  }

  void _handleAutoExpire() async {
    try {
      await _firestore.collection(_currentCollection).doc(_currentReservationId!).update({
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'system',
      });
    } catch (e) {
      DebugHelper.log('Error auto-expiring reservation: $e');
    }
  }

  void _loadReservation() {
    if (_currentReservationId == null) return;
    
    _reservationSubscription = _firestore
        .collection(_currentCollection)
        .doc(_currentReservationId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      if (snapshot.exists) {
        final newReservationData = snapshot.data()!;
        final newStatus = newReservationData['status'] ?? 'unknown';
        final oldStatus = _reservationData?['status'] ?? 'unknown';

        setState(() {
          _reservationData = newReservationData;
          _reservationNotFound = false;
        });

        if (oldStatus != newStatus) {
          _handleStatusChange(oldStatus, newStatus);
        }
      } else {
        setState(() {
          _reservationNotFound = true;
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _reservationNotFound = true;
      });
    });
  }

  void _handleStatusChange(String oldStatus, String newStatus) {
    switch (newStatus) {
      case 'accepted':
      case 'confirmed':
        if (!_hasNotifiedAccepted) {
          _hasNotifiedAccepted = true;
          _showNotification(
            'reservation_confirmed'.tr(),
            'chef_accepted_reservation'.tr(),
            'accepted'
          );
        }
        break;
      case 'declined':
        if (!_hasNotifiedDeclined) {
          _hasNotifiedDeclined = true;
          _showNotification(
            'reservation_declined'.tr(),
            'chef_declined_reservation'.tr(),
            'declined'
          );
        }
        break;
      case 'expired':
        _showNotification(
          'reservation_expired'.tr(),
          'reservation_time_expired'.tr(),
          'expired'
        );
        break;
    }
  }

  void _showNotification(String title, String body, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              type == 'accepted' ? Icons.check_circle : 
              type == 'declined' ? Icons.cancel : Icons.timer_off_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(body)),
          ],
        ),
        backgroundColor: type == 'accepted' ? Colors.green : 
                       type == 'declined' ? Colors.red : Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _cancelReservation() async {
    try {
      if (_currentReservationId == null || _currentDish == null) return;

      await _firestore.runTransaction((transaction) async {
        // Get reservation document
        final reservationDoc = await transaction.get(
          _firestore.collection(_currentCollection).doc(_currentReservationId!)
        );
        
        if (!reservationDoc.exists) {
          throw Exception('Reservation not found');
        }

        final reservationData = reservationDoc.data() as Map<String, dynamic>;
        final currentStatus = reservationData['status'];
        
        // Only allow cancellation if reservation is still pending or accepted
        if (currentStatus != 'pending' && currentStatus != 'accepted') {
          throw Exception('Cannot cancel reservation with status: $currentStatus');
        }

        // Get dish document
        final dishDoc = await transaction.get(_firestore.collection('dishes').doc(_currentDish!.id));
        if (!dishDoc.exists) {
          throw Exception('Dish not found');
        }

        final dishData = dishDoc.data() as Map<String, dynamic>;
        final currentAvailableStock = (dishData['stock'] ?? dishData['quantityAvailable'] ?? 0).toInt();

        // Update reservation status
        transaction.update(reservationDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': 'customer',
        });

        // Restore dish available stock only if reservation was pending or accepted
        if (currentStatus == 'pending' || currentStatus == 'accepted') {
          transaction.update(dishDoc.reference, {
            'stock': currentAvailableStock + (_currentQuantity ?? 1),
            'quantityAvailable': currentAvailableStock + (_currentQuantity ?? 1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      DebugHelper.log('Cancel reservation error: $e');
      _showNotification(
        'cancel_failed'.tr(),
        'try_again_later'.tr(),
        'error'
      );
    }
  }

  void _navigateToCheckout() {
    if (_currentDish == null || _currentQuantity == null || 
        _currentTotalPrice == null || _currentReservationId == null) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          dish: _currentDish!,
          quantity: _currentQuantity!,
          totalPrice: _currentTotalPrice!,
          reservationId: _currentReservationId!,
        ),
      ),
    );
  }

  void _openChatWithChef() {
    if (_currentDish == null || _reservationData == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: 'reservation_$_currentReservationId',
          recipientId: _currentDish!.chefId,
          recipientName: _currentDish!.chefName,
          isOrderChat: true,
        ),
      ),
    );
  }

  void _goBackToDishes() {
    Navigator.pop(context);
  }

  Widget _buildStatusWidget(String status) {
    // Normalize status names
    final normalizedStatus = status == 'confirmed' ? 'accepted' : status;
    
    switch (normalizedStatus) {
      case 'pending':
      case 'reserved':
        return _buildPendingStatus();
      case 'accepted':
        return _buildAcceptedStatus();
      case 'declined':
        return _buildDeclinedStatus();
      case 'expired':
        return _buildExpiredStatus();
      case 'cancelled':
        return _buildCancelledStatus();
      default:
        return _buildUnknownStatus();
    }
  }

  Widget _buildPendingStatus() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: _buildGlassCard(
        gradientColors: [
          Colors.orange.shade50,
          Colors.amber.shade50,
        ],
        borderColor: Colors.orange.shade200,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.timer_rounded, size: 80, color: Colors.orange.shade400),
                Positioned(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Text(
              'waiting_for_chef'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'reservation_expires_in'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.orange.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            
            Text(
              '${_remainingTime.inMinutes}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 20),
            
            LinearProgressIndicator(
              backgroundColor: Colors.orange.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
              value: 1 - (_remainingTime.inSeconds / (5 * 60)),
            ),
            const SizedBox(height: 16),
            
            Text(
              'chef_has_5_minutes_to_accept'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade600,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cancelReservation,
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    label: Text(
                      'cancel_reservation'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.orange.shade400),
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openChatWithChef,
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text('message_chef'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedStatus() {
    return _buildGlassCard(
      gradientColors: [
        Colors.green.shade50,
        Colors.lightGreen.shade50,
      ],
      borderColor: Colors.green.shade200,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, 
                color: Colors.green.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          
          Text(
            'reservation_confirmed'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'chef_accepted_order'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.green.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openChatWithChef,
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: Text('message_chef'.tr()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: mainColor),
                    foregroundColor: mainColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToCheckout,
                  icon: const Icon(Icons.payment_rounded, size: 20),
                  label: Text(
                    'proceed_to_payment'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeclinedStatus() {
    return _buildGlassCard(
      gradientColors: [
        Colors.red.shade50,
        Colors.orange.shade50,
      ],
      borderColor: Colors.red.shade200,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_rounded, 
                color: Colors.red.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          
          Text(
            'reservation_declined'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'chef_declined_reservation'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goBackToDishes,
              icon: const Icon(Icons.restaurant_rounded, size: 20),
              label: Text(
                'browse_other_dishes'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredStatus() {
    return _buildGlassCard(
      gradientColors: [
        Colors.orange.shade50,
        Colors.amber.shade50,
      ],
      borderColor: Colors.orange.shade200,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_off_rounded, 
                color: Colors.orange.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          
          Text(
            'reservation_expired'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'reservation_time_expired'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.orange.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goBackToDishes,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                'try_again'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledStatus() {
    return _buildGlassCard(
      gradientColors: [
        Colors.grey.shade50,
        Colors.grey.shade100,
      ],
      borderColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.do_not_disturb_rounded, 
                color: Colors.grey.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          
          Text(
            'reservation_cancelled'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'reservation_has_been_cancelled'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goBackToDishes,
              icon: const Icon(Icons.restaurant_rounded, size: 20),
              label: Text(
                'browse_dishes'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownStatus() {
    return _buildGlassCard(
      gradientColors: [
        Colors.grey.shade50,
        Colors.grey.shade100,
      ],
      borderColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.help_rounded, 
                color: Colors.grey.shade600, size: 64),
          ),
          const SizedBox(height: 20),
          
          Text(
            'unknown_status'.tr(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            'reservation_status_unknown'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _goBackToDishes,
              icon: const Icon(Icons.home_rounded, size: 20),
              label: Text(
                'go_back'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required List<Color> gradientColors,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReservationSummary() {
    if (_currentDish == null) {
      return _buildGlassCard(
        gradientColors: [Colors.white, Colors.white],
        borderColor: Colors.grey.shade200,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.help_rounded, color: Colors.grey.shade400, size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'loading_dish_info'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'fetching_dish_details'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _buildGlassCard(
      gradientColors: [Colors.white, Colors.white],
      borderColor: Colors.grey.shade200,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(_currentDish!.mainImageUrl),
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
                      _currentDish!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'by_chef'.tr(args: [_currentDish!.chefName]),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.shopping_basket_rounded,
                  label: 'quantity'.tr(),
                  value: 'x${_currentQuantity ?? 1}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.euro_rounded,
                  label: 'total_price'.tr(),
                  value: '${_currentCurrency ?? 'EUR'} ${(_currentTotalPrice ?? 0).toStringAsFixed(2)}',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isHighlighted ? mainColor.withOpacity(0.1) : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isHighlighted ? mainColor : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isHighlighted ? mainColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildReservationNotFound() {
    return _buildGlassCard(
      gradientColors: [Colors.white, Colors.white],
      borderColor: Colors.grey.shade200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 64),
          const SizedBox(height: 20),
          Text(
            'reservation_not_found'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'reservation_no_longer_exists'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return _buildGlassCard(
      gradientColors: [Colors.white, Colors.white],
      borderColor: Colors.red.shade200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, color: Colors.red.shade600, size: 64),
          const SizedBox(height: 20),
          Text(
            'error_loading_reservation'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'please_try_again_later'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidReservationData && _reservationNotFound) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('reservation_status'.tr()),
          centerTitle: true,
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
        ),
        body: Center(
          child: _buildGlassCard(
            gradientColors: [Colors.white, Colors.white],
            borderColor: Colors.grey.shade200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 64),
                const SizedBox(height: 20),
                Text(
                  'no_current_reservation'.tr(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'reservation_not_found_explanation'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goBackToDishes,
                    icon: const Icon(Icons.restaurant_rounded, size: 20),
                    label: Text(
                      'browse_dishes'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('reservation_status'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBackToDishes,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_rounded),
            onPressed: _openChatWithChef,
            tooltip: 'message_chef'.tr(),
          ),
        ],
      ),
      body: _reservationNotFound
          ? Center(child: _buildReservationNotFound())
          : _reservationData == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection(_currentCollection).doc(_currentReservationId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: _buildErrorState());
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return Center(child: _buildReservationNotFound());
                    }

                    final reservationData = snapshot.data!.data() as Map<String, dynamic>;
                    final status = reservationData['status'] ?? 'unknown';

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildReservationSummary(),
                          const SizedBox(height: 32),
                          _buildStatusWidget(status),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}