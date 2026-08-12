// ─────────────────────────────────────────
// Screen: OrderConfirmationScreen
// Description: Post-order success page — shows order ID, payment
//              summary, and animated confirmation feedback.
// Contains: Success animation, order summary, back-to-home CTA
// ─────────────────────────────────────────

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/services/chat_service.dart';
import 'package:odlua/layout/client_orders/client_orders_screen.dart';
import 'package:odlua/app.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _locationData;
  GoogleMapController? _mapController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _loadOrderData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderData() async {
    try {
      final orderDoc =
          await _firestore.collection('orders').doc(widget.orderId).get();

      if (!orderDoc.exists) {
        DebugHelper.log('Order not found: ${widget.orderId}');
        setState(() => _isLoading = false);
        return;
      }

      await Future.delayed(const Duration(seconds: 2));

      final locationDoc = await _firestore
          .collection('orderLocations')
          .doc(widget.orderId)
          .get();

      if (mounted) {
        setState(() {
          _orderData = orderDoc.data();
          _locationData = locationDoc.exists ? locationDoc.data() : null;
          _isLoading = false;
        });

        if (_locationData != null) {
          _setupMapMarkers();
        }

        _animationController.forward();
      }
    } catch (e) {
      DebugHelper.log('Error loading order data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupMapMarkers() {
    final chefAddress = _locationData!['chefAddress'] ?? {};
    final buyerAddress = _locationData!['buyerAddress'] ?? {};

    if (chefAddress['latitude'] != null && chefAddress['longitude'] != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('chef'),
          position: LatLng(
            chefAddress['latitude'],
            chefAddress['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Pickup Location',
            snippet: _orderData!['chefName'] ?? 'Chef',
          ),
        ),
      );
    }

    if (buyerAddress['latitude'] != null && buyerAddress['longitude'] != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('buyer'),
          position: LatLng(
            buyerAddress['latitude'],
            buyerAddress['longitude'],
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Delivery address',
          ),
        ),
      );
    }
  }

  Future<void> _openInMaps() async {
    if (_locationData == null) return;

    final chefAddress = _locationData!['chefAddress'] ?? {};
    final lat = chefAddress['latitude'];
    final lng = chefAddress['longitude'];

    if (lat == null || lng == null) {
      _showSnackBar('Location not available', isError: true);
      return;
    }

    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open maps', isError: true);
    }
  }



  Future<void> _messageChef() async {
    if (_orderData == null) return;

    final chefId = _orderData!['chefId'];
    final chefName = _orderData!['chefName'];

    if (chefId == null) {
      _showSnackBar('Chat information not available', isError: true);
      return;
    }

    if (!mounted) return;

    final result = await ChatService.navigateToChat(
      context: context,
      recipientId: chefId,
      recipientName: chefName ?? 'Chef',
      isOrderChat: true,
      orderId: widget.orderId,
    );

    if (!result.success && mounted) {
      DebugHelper.log('Error creating chat: ${result.error}');
      _showSnackBar('Failed to open chat', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: mainColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing your order details...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_orderData == null) {
      return _buildErrorState();
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildSuccessHeader(),
                  const SizedBox(height: 24),
                  _buildOrderSummaryCard(),
                  const SizedBox(height: 16),
                  if (_locationData != null) ...[
                    _buildMapCard(),
                    const SizedBox(height: 16),
                    _buildLocationDetailsCard(),
                    const SizedBox(height: 16),
                    _buildContactActionsCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                  // Safe area padding at bottom
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'order_not_found'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We couldn\'t find this order. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              ),
              icon: const Icon(Icons.home),
              label: Text('back_to_home'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        ),
      ),
      title: Text(
        'order_confirmation'.tr(),
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSuccessHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [mainColor, mainColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 64,
              color: mainColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'order_placed_successfully'.tr(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'chef_has_been_notified'.tr(),
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long, color: mainColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'order_details'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailRow(
            Icons.numbers,
            'order_id'.tr(),
            widget.orderId.substring(0, 8) + '...',
            copyable: true,
            copyText: widget.orderId,
          ),
          const Divider(height: 24),
          _buildDetailRow(
            Icons.restaurant,
            'dish'.tr(),
            _orderData!['dishName'] ?? 'N/A',
          ),
          const Divider(height: 24),
          _buildDetailRow(
            Icons.person_outline,
            'Chef',
            _orderData!['chefName'] ?? 'N/A',
          ),
          const Divider(height: 24),
          _buildDetailRow(
            Icons.shopping_basket_outlined,
            'quantity'.tr(),
            'x${_orderData!['quantity'] ?? 1}',
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    if (_markers.isEmpty) return const SizedBox.shrink();

    final chefAddress = _locationData!['chefAddress'] ?? {};
    final centerLat = chefAddress['latitude'];
    final centerLng = chefAddress['longitude'];

    if (centerLat == null || centerLng == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(centerLat, centerLng),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _openInMaps,
                backgroundColor: Colors.white,
                icon: Icon(Icons.directions, color: mainColor),
                label: Text(
                  'Open in Maps',
                  style: TextStyle(
                    color: mainColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetailsCard() {
    final chefAddress = _locationData!['chefAddress'] ?? {};
    final distanceKm = _locationData!['distanceKm'] ?? 0.0;
    final travelTime = _locationData!['estimatedTravelTimeMinutes'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.location_on,
                    color: Colors.red.shade400, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'delivery_details'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'pickup_location'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        final address = _formatAddress(chefAddress);
                        Clipboard.setData(ClipboardData(text: address));
                        _showSnackBar('Address copied!');
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatAddress(chefAddress),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.straighten,
                  'distance'.tr(),
                  '${distanceKm.toStringAsFixed(1)} km',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.access_time,
                  'travel_time'.tr(),
                  '~${travelTime.round()} min',
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactActionsCard() {
    final chefPhone = _locationData?['chefPhone'];
    final hasPhone = chefPhone != null && chefPhone.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.support_agent,
                    color: Colors.green.shade400, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Contact Chef',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.chat_bubble,
                  label: 'Message',
                  color: mainColor,
                  onTap: _messageChef,
                ),
              ),
            ],
          ),
          if (hasPhone) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    chefPhone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildLoadingLocationCard() {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 20),
  //     padding: const EdgeInsets.all(24),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(20),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withValues(alpha: 0.05),
  //           blurRadius: 10,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         CircularProgressIndicator(
  //           color: mainColor,
  //           strokeWidth: 2,
  //         ),
  //         const SizedBox(width: 16),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'calculating_delivery_details'.tr(),
  //                 style: const TextStyle(
  //                   fontWeight: FontWeight.w600,
  //                   fontSize: 15,
  //                 ),
  //               ),
  //               const SizedBox(height: 4),
  //               Text(
  //                 'This will only take a moment...',
  //                 style: TextStyle(
  //                   fontSize: 13,
  //                   color: Colors.grey.shade600,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
                (route) => false,
              ),
              icon: const Icon(Icons.receipt_long),
              label: Text(
                'view_my_orders'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: mainColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OdluaLayout()),
                (route) => false,
              ),
              icon: const Icon(Icons.home),
              label: Text(
                'back_to_home'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: mainColor,
                side: BorderSide(color: mainColor, width: 2),
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

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool copyable = false,
    String? copyText,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isHighlighted
                ? mainColor.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isHighlighted ? mainColor : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: isHighlighted ? mainColor : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyText ?? value));
              _showSnackBar('Copied!');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    if (address['street'] != null) parts.add(address['street']);
    if (address['city'] != null) parts.add(address['city']);
    if (address['state'] != null) parts.add(address['state']);
    if (address['postalCode'] != null) parts.add(address['postalCode']);
    if (address['country'] != null) parts.add(address['country']);

    if (parts.isEmpty && address['formattedAddress'] != null) {
      return address['formattedAddress'];
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Address not available';
  }
}
