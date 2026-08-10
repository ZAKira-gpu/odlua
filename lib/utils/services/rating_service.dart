// ─────────────────────────────────────────
// Service: RatingService
// Description: Dish and chef rating CRUD operations.
// Contains: submitRating, getAverageRating
// ─────────────────────────────────────────

/*
// RATING SERVICE TEMPORARILY DISABLED
// This entire file has been commented out to disable the rating system
// All rating functionality is disabled until further notice

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submits a review using a transaction to ensure data consistency across
  /// Users (Chef), Dishes, and Orders.
  Future<Map<String, dynamic>> submitReview({
    required String orderId,
    required String dishId,
    required String chefId,
    required String customerId,
    required String customerName,
    required double rating,
    String? comment,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Get references
        final orderRef = _firestore.collection('orders').doc(orderId);
        final reviewRef = _firestore.collection('reviews').doc(orderId); // Root collection, orderId as doc ID

        // 2. Read Current Data
        final orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) throw Exception("Order not found");

        final orderData = orderDoc.data() as Map<String, dynamic>;
        
        // Safety Check: Eligibility
        final status = orderData['status']?.toString().toLowerCase();
        if (status != 'completed' && status != 'delivered') {
          throw Exception("Only completed or delivered orders can be reviewed");
        }

        if (orderData['isReviewed'] == true) {
          throw Exception("Order already reviewed");
        }

        // 3. Prepare Writes
        
        // A. Create Review Document
        final reviewData = {
          'id': orderId,
          'orderId': orderId,
          'dishId': dishId,
          'chefId': chefId,
          'customerId': customerId,
          'reviewerName': customerName,
          'rating': rating,
          'comment': comment ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        };

        // B. Update Order as Reviewed
        final orderUpdate = {'isReviewed': true};

        // 4. Execute Transaction
        transaction.set(reviewRef, reviewData);
        transaction.update(orderRef, orderUpdate);
      });

      DebugHelper.log('✅ Review submitted successfully for order: $orderId');
      return {'success': true, 'message': 'Review submitted successfully'};

    } catch (e) {
      DebugHelper.log('❌ Error submitting review: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}

*/

// PLACEHOLDER CLASS FOR COMPATIBILITY
class RatingService {
  // All methods disabled - rating system is commented out
  Future<Map<String, dynamic>> submitReview({
    required String orderId,
    required String dishId,
    required String chefId,
    required String customerId,
    required String customerName,
    required double rating,
    String? comment,
  }) async {
    // Disabled - rating system commented out
    return {'success': false, 'error': 'Rating system disabled'};
  }
}
