import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class Dish {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int stock;
  final int availableStock;
  final String chefId;
  final String chefName;
  final List<String> imageUrls;
  final double rating;
  final int ratingsCount;
  final String category;
  final String availabilityType;
  final List<String> tags;
  final List<String> ingredients;
  final Map<String, dynamic>? dietaryOptions;
  final Map<String, bool>? allergies;
  final dynamic location;
  final bool deliveryAvailable;
  final bool pickupAvailable;
  final int preparationTimeMins;
  final bool isAvailable;
  final bool isFeatured;
  final bool isRecommended;
  final Timestamp? expirationDate;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  bool canReserve(int quantity) {
    return stock >= quantity;
  }
  
  // Distance fields
  double distance;
  bool get hasDistance => distance >= 0;
  bool get hasCoordinates => latitude != null && longitude != null;
  double? get latitude {
    if (location is Map) {
      return (location as Map)['lat']?.toDouble();
    }
    return null;
  }
  
  double? get longitude {
    if (location is Map) {
      return (location as Map)['lng']?.toDouble();
    }
    return null;
  }
  
  String get locationString {
    if (location is String) return location;
    if (location is Map) {
      return (location as Map)['address']?.toString() ?? 'Unknown Location';
    }
    return 'Unknown Location';
  }
  
  String get mainImageUrl => imageUrls.isNotEmpty ? imageUrls[0] : '';

  Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.currency = 'EUR',
    required this.stock,
    required this.availableStock,
    required this.chefId,
    required this.chefName,
    required this.imageUrls,
    required this.rating,
    required this.ratingsCount,
    required this.category,
    required this.availabilityType,
    required this.tags,
    required this.ingredients,
    this.dietaryOptions,
    this.allergies,
    required this.location,
    required this.deliveryAvailable,
    required this.pickupAvailable,
    required this.preparationTimeMins,
    required this.isAvailable,
    required this.isFeatured,
    required this.isRecommended,
    this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
    this.distance = -1,
  });

  factory Dish.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Dish(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      currency: data['currency'] ?? 'EUR',
      stock: (data['stock'] ?? 0).toInt(),
      availableStock: (data['availableStock'] ?? data['stock'] ?? 0).toInt(),
      chefId: data['chefID'] ?? '',
      chefName: data['chefName'] ?? 'Chef',
      imageUrls: List<String>.from(data['imageURLs'] ?? []),
      rating: (data['ratingsAverage'] ?? 0.0).toDouble(),
      ratingsCount: (data['ratingsCount'] ?? 0).toInt(),
      category: data['category'] ?? 'other',
      availabilityType: data['availabilityType'] ?? 'sell',
      tags: List<String>.from(data['tags'] ?? []),
      ingredients: List<String>.from(data['ingredients'] ?? []),
      dietaryOptions: Map<String, dynamic>.from(data['dietaryOptions'] ?? {}),
      allergies: Map<String, bool>.from(data['allergies'] ?? {}),
      location: data['location'] ?? {},
      deliveryAvailable: data['deliveryAvailable'] ?? false,
      pickupAvailable: data['pickupAvailable'] ?? false,
      preparationTimeMins: (data['preparationTimeMins'] ?? 30).toInt(),
      isAvailable: data['isAvailable'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
      isRecommended: data['isRecommended'] ?? false,
      expirationDate: data['expirationDate'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'stock': stock,
      'availableStock': availableStock,
      'chefID': chefId,
      'chefName': chefName,
      'imageURLs': imageUrls,
      'ratingsAverage': rating,
      'ratingsCount': ratingsCount,
      'category': category,
      'availabilityType': availabilityType,
      'tags': tags,
      'ingredients': ingredients,
      'dietaryOptions': dietaryOptions,
      'allergies': allergies,
      'location': location,
      'deliveryAvailable': deliveryAvailable,
      'pickupAvailable': pickupAvailable,
      'preparationTimeMins': preparationTimeMins,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isRecommended': isRecommended,
      'expirationDate': expirationDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Dish copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? currency,
    int? stock,
    int? availableStock,
    String? chefId,
    String? chefName,
    List<String>? imageUrls,
    double? rating,
    int? ratingsCount,
    String? category,
    String? availabilityType,
    List<String>? tags,
    List<String>? ingredients,
    Map<String, dynamic>? dietaryOptions,
    Map<String, bool>? allergies,
    dynamic location,
    bool? deliveryAvailable,
    bool? pickupAvailable,
    int? preparationTimeMins,
    bool? isAvailable,
    bool? isFeatured,
    bool? isRecommended,
    Timestamp? expirationDate,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    double? distance,
  }) {
    return Dish(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      stock: stock ?? this.stock,
      availableStock: availableStock ?? this.availableStock,
      chefId: chefId ?? this.chefId,
      chefName: chefName ?? this.chefName,
      imageUrls: imageUrls ?? this.imageUrls,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      category: category ?? this.category,
      availabilityType: availabilityType ?? this.availabilityType,
      tags: tags ?? this.tags,
      ingredients: ingredients ?? this.ingredients,
      dietaryOptions: dietaryOptions ?? this.dietaryOptions,
      allergies: allergies ?? this.allergies,
      location: location ?? this.location,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      pickupAvailable: pickupAvailable ?? this.pickupAvailable,
      preparationTimeMins: preparationTimeMins ?? this.preparationTimeMins,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isRecommended: isRecommended ?? this.isRecommended,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      distance: distance ?? this.distance,
    );
  }
}

class DishService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Dish>> getAllDishes() {
    return _firestore
        .collection('dishes')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Dish.fromFirestore).toList());
  }

  Stream<List<Dish>> getDishesByChef(String chefId) {
    if (chefId.isEmpty) {
      return getAllDishes();
    }
    return _firestore
        .collection('dishes')
        .where('chefID', isEqualTo: chefId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Dish.fromFirestore).toList());
  }

  Future<Dish?> getDishById(String dishId) async {
    try {
      final doc = await _firestore.collection('dishes').doc(dishId).get();
      return doc.exists ? Dish.fromFirestore(doc) : null;
    } catch (e) {
      DebugHelper.log('Error getting dish: $e');
      return null;
    }
  }

  Stream<List<Dish>> getAllDishesWithDistance(LocationService locationService) {
    return _firestore
        .collection('dishes')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final dish = Dish.fromFirestore(doc);
        if (locationService.hasLocation && dish.hasCoordinates) {
          final distance = locationService.calculateDistance(
            locationService.currentPosition!.latitude,
            locationService.currentPosition!.longitude,
            dish.latitude!,
            dish.longitude!,
          );
          return dish.copyWith(distance: distance);
        }
        return dish;
      }).toList();
    });
  }
}


class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  Future<Map<String, dynamic>> createReservation({
    required String dishId,
    required String chefId,
    required String customerId,
    required int quantity,
    required double totalPrice,
    required String currency,
    String? specialInstructions,
    Duration expiryDuration = const Duration(minutes: 5),
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Get dish data
      final dishDoc = await _firestore.collection('dishes').doc(dishId).get();
      if (!dishDoc.exists) {
        return {'success': false, 'error': 'Dish not found'};
      }

      final dishData = dishDoc.data() as Map<String, dynamic>;
      final currentStock = (dishData['stock'] ?? dishData['quantityAvailable'] ?? 0).toInt();

      // Validate stock
      if (currentStock < quantity) {
        return {'success': false, 'error': 'Insufficient stock available'};
      }

      // Create reservation
      final reservationData = {
        'dishId': dishId,
        'dishName': dishData['name'],
        'dishImage': dishData['mainImageUrl'],
        'chefId': chefId,
        'chefName': dishData['chefName'],
        'customerId': customerId,
        'customerName': user.displayName ?? 'Customer',
        'customerEmail': user.email,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'currency': currency,
        'status': 'pending',
        'specialInstructions': specialInstructions,
        'expiresAt': DateTime.now().add(expiryDuration),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final reservationDoc = await _firestore.collection('reservations').add(reservationData);
      final reservationId = reservationDoc.id;

      // Update dish stock
      await _firestore.collection('dishes').doc(dishId).update({
        'stock': currentStock - quantity,
        'quantityAvailable': currentStock - quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to chef
      await _notificationService.sendReservationNotification(
        recipientId: chefId,
        type: 'pending',
        reservationId: reservationId,
        dishName: dishData['name'],
        customerName: user.displayName ?? 'Customer',
      );

      return {
        'success': true,
        'reservationId': reservationId,
        'expiresAt': reservationData['expiresAt'],
      };
    } catch (e) {
      DebugHelper.log('❌ Reservation creation error: $e');
      return {'success': false, 'error': 'Failed to create reservation'};
    }
  }

  Future<bool> updateReservationStatus({
    required String reservationId,
    required String status,
    required String updatedBy,
    String? reason,
  }) async {
    try {
      final reservationDoc = await _firestore.collection('reservations').doc(reservationId).get();
      if (!reservationDoc.exists) {
        return false;
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final currentStatus = reservationData['status'];

      // Prevent updating completed/cancelled reservations
      if (['completed', 'cancelled', 'expired'].contains(currentStatus)) {
        return false;
      }

      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };

      // Add status-specific timestamps
      switch (status) {
        case 'accepted':
          updateData['acceptedAt'] = FieldValue.serverTimestamp();
          break;
        case 'declined':
          updateData['declinedAt'] = FieldValue.serverTimestamp();
          if (reason != null) updateData['declineReason'] = reason;
          break;
        case 'completed':
          updateData['completedAt'] = FieldValue.serverTimestamp();
          break;
        case 'cancelled':
          updateData['cancelledAt'] = FieldValue.serverTimestamp();
          updateData['cancelledBy'] = updatedBy;
          break;
      }

      await _firestore.collection('reservations').doc(reservationId).update(updateData);

      // Send notification based on status
      final recipientId = status == 'accepted' ? reservationData['customerId'] : reservationData['chefId'];
      
      await _notificationService.sendReservationNotification(
        recipientId: recipientId,
        type: status,
        reservationId: reservationId,
        dishName: reservationData['dishName'],
        customerName: reservationData['customerName'],
        chefName: reservationData['chefName'],
        reason: reason,
      );

      return true;
    } catch (e) {
      DebugHelper.log('❌ Reservation status update error: $e');
      return false;
    }
  }

  Future<void> expireReservations() async {
    try {
      final now = DateTime.now();
      final expiredReservations = await _firestore
          .collection('reservations')
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isLessThan: now)
          .get();

      for (final doc in expiredReservations.docs) {
        await updateReservationStatus(
          reservationId: doc.id,
          status: 'expired',
          updatedBy: 'system',
        );
      }
    } catch (e) {
      DebugHelper.log('❌ Expire reservations error: $e');
    }
  }
}