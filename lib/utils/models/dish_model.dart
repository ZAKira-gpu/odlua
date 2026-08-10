// ─────────────────────────────────────────
// Model: DishModel
// Description: Dart model for the Firestore dishes collection.
// Contains: fromMap, toMap, price, rating, availability
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:odlua/utils/location/location_services.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/models/structured_address_model.dart';

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
  final dynamic location; // Legacy location field (Map or String)
  final StructuredAddress? exactLocation; // NEW: Precise structured address
  final double? deliveryRadius; // Max delivery distance in km (default: 10km)
  final List<String>? deliveryZones; // Specific postal codes or areas served
  final bool deliveryAvailable;
  final bool pickupAvailable;
  final int preparationTimeMins;
  final bool isAvailable;
  final bool isFeatured;
  final bool isRecommended;
  final Timestamp? expirationDate;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool hideAddressTitle; // Chef privacy: hide name on cards
  final bool isDaily; // Daily refresh mode
  final int dailyQuantity; // Servings per day when isDaily is true
  final String? lastRefreshDate; // Date of last daily stock reset (yyyy-MM-dd)

  /// Check if the dish has expired based on its expirationDate
  bool get isExpired {
    if (expirationDate == null) return false;
    return expirationDate!.toDate().isBefore(DateTime.now());
  }

  bool canReserve(int quantity) {
    return stock >= quantity;
  }

  // Distance fields
  double distance;
  bool get hasDistance => distance >= 0;
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Extracts latitude from the best available source.
  /// Priority: exactLocation (StructuredAddress) → legacy location Map.
  /// Legacy maps may store lat under 'lat', 'latitude', '_latitude',
  /// or nested in 'geometry.lat'.
  double? get latitude {
    // First try exactLocation (new structured address)
    if (exactLocation != null) {
      return exactLocation!.coordinates.latitude;
    }

    // Fallback to legacy location field
    if (location is Map) {
      final loc = location as Map;
      // common variants
      final candidates = [
        loc['lat'],
        loc['latitude'],
        loc['_latitude'],
      ];
      for (final c in candidates) {
        if (c != null) {
          try {
            return (c as num).toDouble();
          } catch (_) {}
        }
      }

      // sometimes nested under a 'geometry' or 'position' object
      if (loc['geometry'] is Map) {
        final g = loc['geometry'] as Map;
        if (g['lat'] != null) return (g['lat'] as num).toDouble();
        if (g['latitude'] != null) return (g['latitude'] as num).toDouble();
      }
    }
    return null;
  }

  /// Extracts longitude from the best available source.
  /// Mirror logic of [latitude] with keys 'lng', 'lon', 'longitude', '_longitude'.
  double? get longitude {
    // First try exactLocation (new structured address)
    if (exactLocation != null) {
      return exactLocation!.coordinates.longitude;
    }

    // Fallback to legacy location field
    if (location is Map) {
      final loc = location as Map;
      final candidates = [
        loc['lng'],
        loc['lon'],
        loc['longitude'],
        loc['_longitude'],
      ];
      for (final c in candidates) {
        if (c != null) {
          try {
            return (c as num).toDouble();
          } catch (_) {}
        }
      }

      if (loc['geometry'] is Map) {
        final g = loc['geometry'] as Map;
        if (g['lng'] != null) return (g['lng'] as num).toDouble();
        if (g['longitude'] != null) return (g['longitude'] as num).toDouble();
      }
    }
    return null;
  }

  /// Returns the city name if available in the location map.
  String? get city {
    // First try exactLocation (new structured address)
    if (exactLocation != null) {
      return exactLocation!.city;
    }

    // Fallback to legacy location field
    if (location is Map) {
      final loc = location as Map;
      // direct common keys
      if (loc['city'] != null) return loc['city'].toString();
      if (loc['town'] != null) return loc['town'].toString();
      if (loc['municipality'] != null) return loc['municipality'].toString();

      // nested address object
      final addr = loc['address'];
      if (addr is Map) {
        if (addr['city'] != null) return addr['city'].toString();
        if (addr['town'] != null) return addr['town'].toString();
        if (addr['municipality'] != null)
          return addr['municipality'].toString();
      }

      // Geoapify style: properties or formatted address can be parsed later if needed
      if (loc['properties'] is Map) {
        final p = loc['properties'] as Map;
        if (p['city'] != null) return p['city'].toString();
      }
    }
    return null;
  }

  /// Returns postal code if available in location map.
  String? get postalCode {
    // First try exactLocation (new structured address)
    if (exactLocation != null) {
      return exactLocation!.postalCode;
    }

    // Fallback to legacy location field
    if (location is Map) {
      final loc = location as Map;
      final keys = ['postalCode', 'postal_code', 'postcode', 'zip'];
      for (final k in keys) {
        if (loc[k] != null) return loc[k].toString();
      }
      final addr = loc['address'];
      if (addr is Map) {
        for (final k in keys) {
          if (addr[k] != null) return addr[k].toString();
        }
      }
      if (loc['properties'] is Map) {
        final p = loc['properties'] as Map;
        for (final k in keys) {
          if (p[k] != null) return p[k].toString();
        }
      }
    }
    return null;
  }

  String get locationString {
    if (exactLocation != null) {
      // Return appropriate tier based on context
      return exactLocation!.toPublicAddress(); // Default to public for browsing
    }
    if (location is String) return location;
    if (location is Map) {
      return (location as Map)['address']?.toString() ?? 'Unknown Location';
    }
    return 'Unknown Location';
  }

  /// Get street name from exactLocation (TIER 2)
  String? get streetName {
    return exactLocation?.streetName;
  }

  /// Get full structured address (TIER 3 - only after order)
  String? get fullAddress {
    return exactLocation?.toFullAddress();
  }

  /// Get approximate address for dish details (TIER 2)
  String? get approximateAddress {
    return exactLocation?.toApproximateAddress();
  }

  /// Check if buyer is within delivery zone
  /// Checks if the buyer is within the chef’s delivery zone.
  /// First checks postal-code match (if deliveryZones set), then falls back
  /// to a Haversine radius check.
  bool isInDeliveryZone({
    required double buyerLatitude,
    required double buyerLongitude,
    String? buyerPostalCode,
  }) {
    // If no delivery zones specified, check radius only
    if (deliveryZones == null || deliveryZones!.isEmpty) {
      return isWithinDeliveryRadius(buyerLatitude, buyerLongitude);
    }

    // If postal codes are specified, check if buyer's postal code matches
    if (buyerPostalCode != null && buyerPostalCode.isNotEmpty) {
      return deliveryZones!.contains(buyerPostalCode);
    }

    // Fallback to radius check
    return isWithinDeliveryRadius(buyerLatitude, buyerLongitude);
  }

  /// Check if buyer is within delivery radius
  bool isWithinDeliveryRadius(double buyerLatitude, double buyerLongitude) {
    if (!hasCoordinates || !deliveryAvailable) return false;

    final maxRadius = deliveryRadius ?? 10.0; // Default 10km

    // Calculate distance using Haversine formula
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(buyerLatitude - latitude!);
    final dLng = _degreesToRadians(buyerLongitude - longitude!);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_degreesToRadians(latitude!)) *
            _cos(_degreesToRadians(buyerLatitude)) *
            _sin(dLng / 2) *
            _sin(dLng / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    final calculatedDistance = earthRadiusKm * c;

    return calculatedDistance <= maxRadius;
  }

  /// Get obfuscated coordinates for TIER 2 display
  /// Uses consistent seed to prevent location "jumping"
  GeoPoint? getObfuscatedCoordinates() {
    if (exactLocation == null) return null;

    // Use dish ID as seed for consistent obfuscation
    return exactLocation!.getObfuscatedCoordinates(
      seed: id,
      minOffsetMeters: 200,
      maxOffsetMeters: 500,
    );
  }

  // Math helper methods
  static double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
  static double _sin(double x) => math.sin(x);
  static double _cos(double x) => math.cos(x);
  static double _sqrt(double x) => math.sqrt(x);
  static double _atan2(double y, double x) => math.atan2(y, x);

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
    this.exactLocation,
    this.deliveryRadius,
    this.deliveryZones,
    required this.deliveryAvailable,
    required this.pickupAvailable,
    required this.preparationTimeMins,
    required this.isAvailable,
    required this.isFeatured,
    required this.isRecommended,
    this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
    this.hideAddressTitle = false,
    this.isDaily = false,
    this.dailyQuantity = 0,
    this.lastRefreshDate,
    this.distance = -1,
  });

  /// Deserialises a Firestore document into a [Dish].
  ///
  /// Handles 30+ fields with safe casting, legacy location formats,
  /// StructuredAddress, and Timestamp validation. Throws on null data.
  factory Dish.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    if (rawData == null) {
      DebugHelper.log(
          '🍽️ Dish.fromFirestore: ❌ Document ${doc.id} has null data');
      throw Exception('Document ${doc.id} has null data');
    }

    final data = rawData as Map<String, dynamic>;
    DebugHelper.log('🍽️ Dish.fromFirestore: Parsing dish ${doc.id}');

    // Parse exactLocation if present
    StructuredAddress? exactLoc;
    if (data['exactLocation'] != null && data['exactLocation'] is Map) {
      try {
        exactLoc = StructuredAddress.fromFirestore(
          data['exactLocation'] as Map<String, dynamic>,
        );
      } catch (e) {
        DebugHelper.log(
            '🍽️ Dish.fromFirestore: Error parsing exactLocation for ${doc.id}: $e');
      }
    }

    // Safe parsing helpers
    double safeDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    int safeInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    List<String> safeStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return [];
    }

    Map<String, dynamic> safeDynamicMap(dynamic value) {
      if (value == null) return {};
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return {};
    }

    Map<String, bool> safeBoolMap(dynamic value) {
      if (value == null) return {};
      if (value is Map) {
        final result = <String, bool>{};
        value.forEach((key, val) {
          if (key is String && val is bool) {
            result[key] = val;
          }
        });
        return result;
      }
      return {};
    }

    try {
      return Dish(
        id: doc.id,
        name: (data['name'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        price: safeDouble(data['price']),
        currency: (data['currency'] ?? 'EUR').toString(),
        stock: safeInt(data['stock']),
        availableStock: safeInt(data['availableStock'] ?? data['stock']),
        chefId: (data['chefID'] ?? '').toString(),
        chefName: (data['chefName'] ?? 'Chef').toString(),
        imageUrls: safeStringList(data['imageURLs']),
        rating: safeDouble(data['ratingsAverage']),
        ratingsCount: safeInt(data['ratingsCount']),
        category: (data['category'] ?? 'other').toString(),
        availabilityType: (data['availabilityType'] ?? 'sell').toString(),
        tags: safeStringList(data['tags']),
        ingredients: safeStringList(data['ingredients']),
        dietaryOptions: safeDynamicMap(data['dietaryOptions']),
        allergies: safeBoolMap(data['allergies']),
        location: data['location'] ?? {},
        exactLocation: exactLoc,
        deliveryRadius: data['deliveryRadius'] != null
            ? safeDouble(data['deliveryRadius'])
            : null,
        deliveryZones: data['deliveryZones'] != null
            ? safeStringList(data['deliveryZones'])
            : null,
        deliveryAvailable: data['deliveryAvailable'] == true,
        pickupAvailable: data['pickupAvailable'] == true,
        preparationTimeMins: safeInt(data['preparationTimeMins'], 30),
        // isAvailable: only true if manually available AND has stock AND not expired
        isAvailable: data['isAvailable'] != false &&
            safeInt(data['availableStock'] ?? data['stock']) > 0 &&
            !(data['expirationDate'] is Timestamp &&
                (data['expirationDate'] as Timestamp)
                    .toDate()
                    .isBefore(DateTime.now())),
        isFeatured: data['isFeatured'] == true,
        isRecommended: data['isRecommended'] == true,
        expirationDate:
            data['expirationDate'] is Timestamp ? data['expirationDate'] : null,
        createdAt: data['createdAt'] is Timestamp
            ? data['createdAt']
            : Timestamp.now(),
        updatedAt: data['updatedAt'] is Timestamp
            ? data['updatedAt']
            : Timestamp.now(),
        hideAddressTitle: data['hideAddressTitle'] == true,
        isDaily: data['isDaily'] == true,
        dailyQuantity: safeInt(data['dailyQuantity']),
        lastRefreshDate: data['lastRefreshDate']?.toString(),
      );
    } catch (e, stackTrace) {
      DebugHelper.log(
          '🍽️ Dish.fromFirestore: ❌ Error creating Dish object for ${doc.id}: $e');
      DebugHelper.log('🍽️ Dish.fromFirestore: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    final map = {
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
      'city': city, // Added for server-side search
      'postalCode': postalCode, // Added for server-side search
      'availabilityType': availabilityType,
      'tags': tags,
      'ingredients': ingredients,
      'dietaryOptions': dietaryOptions,
      'allergies': allergies,
      'location': location,
      'deliveryRadius': deliveryRadius,
      'deliveryZones': deliveryZones,
      'deliveryAvailable': deliveryAvailable,
      'pickupAvailable': pickupAvailable,
      'preparationTimeMins': preparationTimeMins,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isRecommended': isRecommended,
      'expirationDate': expirationDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'hideAddressTitle': hideAddressTitle,
      'isDaily': isDaily,
      'dailyQuantity': dailyQuantity,
      if (lastRefreshDate != null) 'lastRefreshDate': lastRefreshDate,
    };

    // Add exactLocation if present
    if (exactLocation != null) {
      map['exactLocation'] = exactLocation!.toFirestore();
    }

    return map;
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
    StructuredAddress? exactLocation,
    double? deliveryRadius,
    List<String>? deliveryZones,
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
    bool? hideAddressTitle,
    bool? isDaily,
    int? dailyQuantity,
    String? lastRefreshDate,
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
      exactLocation: exactLocation ?? this.exactLocation,
      deliveryRadius: deliveryRadius ?? this.deliveryRadius,
      deliveryZones: deliveryZones ?? this.deliveryZones,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      pickupAvailable: pickupAvailable ?? this.pickupAvailable,
      preparationTimeMins: preparationTimeMins ?? this.preparationTimeMins,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isRecommended: isRecommended ?? this.isRecommended,
      expirationDate: expirationDate ?? this.expirationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hideAddressTitle: hideAddressTitle ?? this.hideAddressTitle,
      isDaily: isDaily ?? this.isDaily,
      dailyQuantity: dailyQuantity ?? this.dailyQuantity,
      lastRefreshDate: lastRefreshDate ?? this.lastRefreshDate,
      distance: distance ?? this.distance,
    );
  }
}

class DishService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all dishes from Firestore as a stream
  /// Returns an empty list on error to prevent stream from breaking
  Stream<List<Dish>> getAllDishes() {
    DebugHelper.log('🍽️ DishService: Starting getAllDishes stream...');
    return _firestore
        .collection('dishes')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      DebugHelper.log(
          '🍽️ DishService: Received ${snapshot.docs.length} documents from Firestore');
      final dishes = <Dish>[];
      for (final doc in snapshot.docs) {
        try {
          final dish = Dish.fromFirestore(doc);
          dishes.add(dish);
        } catch (e, stackTrace) {
          DebugHelper.log(
              '🍽️ DishService: ❌ Error parsing dish ${doc.id}: $e');
          DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
          // Skip invalid dishes but continue processing others
        }
      }
      DebugHelper.log(
          '🍽️ DishService: ✅ Successfully parsed ${dishes.length} dishes');
      return dishes;
    }).handleError((error, stackTrace) {
      DebugHelper.log('🍽️ DishService: ❌ Stream error: $error');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
      // Return empty list to prevent stream from breaking
      return <Dish>[];
    }, test: (error) => true);
  }

  /// Get dishes by chef ID as a stream
  /// Returns all dishes if chefId is empty
  Stream<List<Dish>> getDishesByChef(String chefId) {
    if (chefId.isEmpty) {
      DebugHelper.log(
          '🍽️ DishService: getDishesByChef called with empty chefId, returning all dishes');
      return getAllDishes();
    }
    DebugHelper.log('🍽️ DishService: Getting dishes for chef: $chefId');
    return _firestore
        .collection('dishes')
        .where('chefID', isEqualTo: chefId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      DebugHelper.log(
          '🍽️ DishService: Received ${snapshot.docs.length} dishes for chef $chefId');
      final dishes = <Dish>[];
      for (final doc in snapshot.docs) {
        try {
          dishes.add(Dish.fromFirestore(doc));
        } catch (e, stackTrace) {
          DebugHelper.log(
              '🍽️ DishService: ❌ Error parsing dish ${doc.id}: $e');
          DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
          // Skip invalid dishes but continue processing
        }
      }
      return dishes;
    }).handleError((error, stackTrace) {
      DebugHelper.log('🍽️ DishService: ❌ getDishesByChef error: $error');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
      return <Dish>[];
    }, test: (error) => true);
  }

  /// Get a single dish by ID
  /// Returns null if dish not found or on error
  Future<Dish?> getDishById(String dishId) async {
    if (dishId.isEmpty) {
      DebugHelper.log('🍽️ DishService: getDishById called with empty dishId');
      return null;
    }

    try {
      DebugHelper.log('🍽️ DishService: Getting dish by ID: $dishId');
      final doc = await _firestore.collection('dishes').doc(dishId).get();

      if (!doc.exists) {
        DebugHelper.log('🍽️ DishService: Dish $dishId not found');
        return null;
      }

      final dish = Dish.fromFirestore(doc);
      DebugHelper.log(
          '🍽️ DishService: ✅ Successfully loaded dish: ${dish.name}');
      return dish;
    } on FirebaseException catch (e, stackTrace) {
      DebugHelper.log(
          '🍽️ DishService: ❌ Firebase error getting dish $dishId: ${e.code} - ${e.message}');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
      return null;
    } catch (e, stackTrace) {
      DebugHelper.log('🍽️ DishService: ❌ Error getting dish $dishId: $e');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get all dishes with calculated distance from user's location
  /// Falls back to dishes without distance if location is unavailable
  Stream<List<Dish>> getAllDishesWithDistance(LocationService locationService) {
    DebugHelper.log(
        '🍽️ DishService: Starting getAllDishesWithDistance stream...');
    return _firestore
        .collection('dishes')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      DebugHelper.log(
          '🍽️ DishService: Processing ${snapshot.docs.length} dishes for distance calculation');
      final dishes = <Dish>[];

      for (final doc in snapshot.docs) {
        try {
          var dish = Dish.fromFirestore(doc);

          // Calculate distance if both user location and dish coordinates are available
          if (locationService.hasLocation &&
              dish.hasCoordinates &&
              locationService.currentPosition != null) {
            try {
              final pos = locationService.currentPosition;
              double? lat;
              double? lng;

              // Safely extract coordinates from position
              if (pos != null) {
                lat = _safeDouble(pos['latitude']);
                lng = _safeDouble(pos['longitude']);
              }

              if (lat != null &&
                  lng != null &&
                  dish.latitude != null &&
                  dish.longitude != null) {
                final distance = locationService.calculateDistance(
                  lat,
                  lng,
                  dish.latitude!,
                  dish.longitude!,
                );
                dish = dish.copyWith(distance: distance);
              }
            } catch (distanceError) {
              DebugHelper.log(
                  '🍽️ DishService: ⚠️ Could not calculate distance for dish ${doc.id}: $distanceError');
              // Continue with dish without distance
            }
          }
          dishes.add(dish);
        } catch (e, stackTrace) {
          DebugHelper.log(
              '🍽️ DishService: ❌ Error parsing dish ${doc.id}: $e');
          DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
          // Skip invalid dishes but continue processing
        }
      }

      DebugHelper.log(
          '🍽️ DishService: ✅ Processed ${dishes.length} dishes with distance');
      return dishes;
    }).handleError((error, stackTrace) {
      DebugHelper.log(
          '🍽️ DishService: ❌ getAllDishesWithDistance error: $error');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
    }, test: (error) => true);
  }

  /// Safely convert dynamic value to double
  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Search dishes with server-side filtering
  /// Returns a stream of dishes matching the search criteria
  Stream<List<Dish>> searchDishes({
    String? category,
    String? city,
    String? postalCode,
    String? availabilityType,
  }) {
    DebugHelper.log(
        '🍽️ DishService: Searching dishes - category: $category, city: $city, postalCode: $postalCode, type: $availabilityType');

    Query query = _firestore.collection('dishes');

    if (category != null && category != 'all' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }

    if (postalCode != null && postalCode.isNotEmpty) {
      query = query.where('postalCode', isEqualTo: postalCode);
    }

    if (availabilityType != null && availabilityType.isNotEmpty) {
      query = query.where('availabilityType', isEqualTo: availabilityType);
    }

    return query.snapshots().map((snapshot) {
      DebugHelper.log(
          '🍽️ DishService: Search returned ${snapshot.docs.length} results');
      final dishes = <Dish>[];
      for (final doc in snapshot.docs) {
        try {
          dishes.add(Dish.fromFirestore(doc));
        } catch (e, stackTrace) {
          DebugHelper.log(
              '🍽️ DishService: ❌ Error parsing dish ${doc.id}: $e');
          DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
          // Skip invalid dishes but continue processing
        }
      }
      return dishes;
    }).handleError((error, stackTrace) {
      DebugHelper.log('🍽️ DishService: ❌ searchDishes error: $error');
      DebugHelper.log('🍽️ DishService: Stack trace: $stackTrace');
    }, test: (error) => true);
  }
}

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// Safely convert dynamic value to int
  static int _safeInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// Create a new reservation for a dish
  /// Returns a map with success status and either reservationId or error message
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
    // Parameter validation
    if (dishId.isEmpty) {
      return {'success': false, 'error': 'Invalid dish ID'};
    }
    if (chefId.isEmpty) {
      return {'success': false, 'error': 'Invalid chef ID'};
    }
    if (customerId.isEmpty) {
      return {'success': false, 'error': 'Invalid customer ID'};
    }
    if (quantity <= 0) {
      return {'success': false, 'error': 'Quantity must be greater than 0'};
    }
    if (totalPrice < 0) {
      return {'success': false, 'error': 'Total price cannot be negative'};
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Fetch consumer phone number from user document for denormalization
      String? consumerPhone;
      bool missingPhone = false;
      try {
        final userDoc =
            await _firestore.collection('users').doc(customerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          consumerPhone = userData['phone']?.toString().trim();
          // If phone is null/empty, fallback to email and flag as missing
          if (consumerPhone == null || consumerPhone.isEmpty) {
            consumerPhone = user.email ?? '';
            missingPhone = true;
          }
        } else {
          // User doc not found, fallback to email
          consumerPhone = user.email ?? '';
          missingPhone = true;
        }
      } catch (e) {
        // Error fetching user, fallback to email
        consumerPhone = user.email ?? '';
        missingPhone = true;
        DebugHelper.log('Error fetching user phone: $e');
      }

      final reservationId = _firestore.collection('reservations').doc().id;
      final expiresAt = DateTime.now().add(expiryDuration);

      // Get dish data for notification (before transaction)
      // This is safe because transaction will re-validate stock
      final preTransactionDishDoc =
          await _firestore.collection('dishes').doc(dishId).get();
      if (!preTransactionDishDoc.exists) {
        return {'success': false, 'error': 'Dish not found'};
      }
      final preTransactionDishData =
          preTransactionDishDoc.data() as Map<String, dynamic>;
      final dishName =
          preTransactionDishData['name']?.toString() ?? 'Unknown Dish';
      final chefName = preTransactionDishData['chefName']?.toString() ?? 'Chef';

      // Safely extract dish image - try imageURLs first, then mainImageUrl
      String? dishImage;
      final imageUrls = preTransactionDishData['imageURLs'];
      if (imageUrls is List && imageUrls.isNotEmpty) {
        dishImage = imageUrls.first?.toString();
      }
      dishImage ??= preTransactionDishData['mainImageUrl']?.toString();

      // Perform reservation creation and stock update in a single transaction
      await _firestore.runTransaction((transaction) async {
        // Get dish document in transaction (fresh read for stock validation)
        final dishDoc =
            await transaction.get(_firestore.collection('dishes').doc(dishId));

        if (!dishDoc.exists) {
          throw Exception('Dish not found');
        }

        final dishData = dishDoc.data() as Map<String, dynamic>;

        // CRITICAL FIX: Handle missing availableStock field by falling back to stock
        // Use availableStock if present, otherwise fall back to stock, then quantityAvailable
        int currentStock = 0;
        if (dishData.containsKey('availableStock') &&
            dishData['availableStock'] != null) {
          currentStock = _safeInt(dishData['availableStock']);
        } else if (dishData.containsKey('stock') && dishData['stock'] != null) {
          currentStock = _safeInt(dishData['stock']);
        } else if (dishData.containsKey('quantityAvailable') &&
            dishData['quantityAvailable'] != null) {
          currentStock = _safeInt(dishData['quantityAvailable']);
        }

        // Validate stock
        if (currentStock < quantity) {
          throw Exception(
              'Insufficient stock available. Only $currentStock items left.');
        }

        // Create reservation data
        final reservationData = {
          'dishId': dishId,
          'dishName': dishName,
          'dishImage': dishImage ?? '',
          'chefId': chefId,
          'chefName': chefName,
          'customerId': customerId,
          'customerName': user.displayName ?? 'Customer',
          'customerEmail': user.email ?? '',
          'consumerPhone': consumerPhone ?? '',
          'missingPhone': missingPhone,
          'quantity': quantity,
          'totalPrice': totalPrice,
          'currency': currency,
          'status': 'pending',
          'specialInstructions': specialInstructions ?? '',
          'expiresAt': expiresAt,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Create reservation document in transaction
        transaction.set(
          _firestore.collection('reservations').doc(reservationId),
          reservationData,
        );

        // Update dish stock in transaction - decrement the appropriate field
        if (dishData.containsKey('availableStock') &&
            dishData['availableStock'] != null) {
          transaction.update(dishDoc.reference, {
            'availableStock': currentStock - quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (dishData.containsKey('stock') && dishData['stock'] != null) {
          transaction.update(dishDoc.reference, {
            'stock': currentStock - quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Update all stock-related fields for maximum compatibility
          transaction.update(dishDoc.reference, {
            'stock': currentStock - quantity,
            'availableStock': currentStock - quantity,
            'quantityAvailable': currentStock - quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Send notification to chef after transaction commits
      await _notificationService.sendReservationNotification(
        recipientId: chefId,
        type: 'pending',
        reservationId: reservationId,
        dishName: dishName,
        customerName: user.displayName ?? 'Customer',
      );

      return {
        'success': true,
        'reservationId': reservationId,
        'expiresAt': expiresAt,
      };
    } catch (e) {
      DebugHelper.log('❌ Reservation creation error: $e');
      return {'success': false, 'error': 'Failed to create reservation'};
    }
  }

  /// Update the status of a reservation
  /// Returns true if successful, false otherwise
  /// Handles stock restoration for cancelled/declined/expired orders
  Future<bool> updateReservationStatus({
    required String reservationId,
    required String status,
    required String updatedBy,
    String? reason,
  }) async {
    // Parameter validation
    if (reservationId.isEmpty) {
      DebugHelper.log('❌ updateReservationStatus: Invalid reservation ID');
      return false;
    }
    if (status.isEmpty) {
      DebugHelper.log('❌ updateReservationStatus: Invalid status');
      return false;
    }
    if (updatedBy.isEmpty) {
      DebugHelper.log('❌ updateReservationStatus: Invalid updatedBy');
      return false;
    }

    // Validate status is a known value
    const validStatuses = [
      'pending',
      'accepted',
      'declined',
      'completed',
      'cancelled',
      'expired'
    ];
    if (!validStatuses.contains(status)) {
      DebugHelper.log('❌ updateReservationStatus: Unknown status: $status');
      return false;
    }

    try {
      final reservationDoc =
          await _firestore.collection('reservations').doc(reservationId).get();
      if (!reservationDoc.exists) {
        DebugHelper.log(
            '❌ updateReservationStatus: Reservation $reservationId not found');
        return false;
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final currentStatus = reservationData['status']?.toString() ?? '';

      // Prevent updating completed/cancelled reservations
      if (['completed', 'cancelled', 'expired'].contains(currentStatus)) {
        DebugHelper.log(
            '⚠️ updateReservationStatus: Cannot update $currentStatus reservation');
        return false;
      }

      final updateData = <String, dynamic>{
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
          if (reason != null && reason.isNotEmpty) {
            updateData['declineReason'] = reason;
          }
          break;
        case 'completed':
          updateData['completedAt'] = FieldValue.serverTimestamp();
          break;
        case 'cancelled':
          updateData['cancelledAt'] = FieldValue.serverTimestamp();
          updateData['cancelledBy'] = updatedBy;
          if (reason != null && reason.isNotEmpty) {
            updateData['cancellationReason'] = reason;
          }
          break;
        case 'expired':
          updateData['expiredAt'] = FieldValue.serverTimestamp();
          break;
      }

      await _firestore
          .collection('reservations')
          .doc(reservationId)
          .update(updateData);

      DebugHelper.log('✅ Reservation $reservationId status updated to $status');

      // CRITICAL: Restore stock when order is cancelled, declined, or expired
      if (['cancelled', 'declined', 'expired'].contains(status)) {
        final quantity = _safeInt(reservationData['quantity']);
        final dishId = reservationData['dishId']?.toString();

        if (dishId != null && dishId.isNotEmpty && quantity > 0) {
          try {
            await _firestore.collection('dishes').doc(dishId).update({
              'stock': FieldValue.increment(quantity),
              'quantityAvailable': FieldValue.increment(quantity),
              'availableStock': FieldValue.increment(quantity),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            DebugHelper.log('✅ Stock restored: +$quantity for dish $dishId');
          } catch (stockError) {
            // Log but don't fail the whole operation
            DebugHelper.log(
                '⚠️ Failed to restore stock for dish $dishId: $stockError');
          }
        }
      }

      // Send notification based on status (non-blocking)
      try {
        final recipientId = status == 'accepted'
            ? reservationData['customerId']?.toString()
            : reservationData['chefId']?.toString();

        if (recipientId != null && recipientId.isNotEmpty) {
          await _notificationService.sendReservationNotification(
            recipientId: recipientId,
            type: status,
            reservationId: reservationId,
            dishName: reservationData['dishName']?.toString() ?? 'Unknown',
            customerName:
                reservationData['customerName']?.toString() ?? 'Customer',
            chefName: reservationData['chefName']?.toString() ?? 'Chef',
            reason: reason,
          );
        }
      } catch (notificationError) {
        // Log but don't fail the operation
        DebugHelper.log('⚠️ Failed to send notification: $notificationError');
      }

      return true;
    } on FirebaseException catch (e, stackTrace) {
      DebugHelper.log(
          '❌ Reservation status update Firebase error: ${e.code} - ${e.message}');
      DebugHelper.log('Stack trace: $stackTrace');
      return false;
    } catch (e, stackTrace) {
      DebugHelper.log('❌ Reservation status update error: $e');
      DebugHelper.log('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Expire all pending reservations that have passed their expiry time
  /// This should be called periodically (e.g., by a cloud function or app startup)
  Future<void> expireReservations() async {
    try {
      DebugHelper.log('🕐 Checking for expired reservations...');
      final now = DateTime.now();

      final expiredReservations = await _firestore
          .collection('reservations')
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isLessThan: now)
          .get();

      if (expiredReservations.docs.isEmpty) {
        DebugHelper.log('🕐 No expired reservations found');
        return;
      }

      DebugHelper.log(
          '🕐 Found ${expiredReservations.docs.length} expired reservations');

      int successCount = 0;
      int failCount = 0;

      for (final doc in expiredReservations.docs) {
        try {
          final success = await updateReservationStatus(
            reservationId: doc.id,
            status: 'expired',
            updatedBy: 'system',
          );
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          DebugHelper.log('⚠️ Failed to expire reservation ${doc.id}: $e');
          failCount++;
        }
      }

      DebugHelper.log(
          '🕐 Expiration complete: $successCount succeeded, $failCount failed');
    } on FirebaseException catch (e, stackTrace) {
      DebugHelper.log(
          '❌ Expire reservations Firebase error: ${e.code} - ${e.message}');
      DebugHelper.log('Stack trace: $stackTrace');
    } catch (e, stackTrace) {
      DebugHelper.log('❌ Expire reservations error: $e');
      DebugHelper.log('Stack trace: $stackTrace');
    }
  }
}
