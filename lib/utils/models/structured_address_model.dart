// ─────────────────────────────────────────
// Model: StructuredAddress
// Description: Structured address with street, city, country, coordinates.
// Contains: fromMap, toMap, displayString
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/location/services/location_obfuscation_service.dart';

/// Structured address model for precise location collection
/// Supports step-by-step input and 3-tier privacy architecture
class StructuredAddress {
  // Level 1: City (always required)
  final String city;
  final String? cityCode; // e.g., "cairo", "alex" for filtering
  final String country;
  final String? countryCode; // e.g., "EG", "SA", "AE"

  // Level 2: Street (required for precise location)
  final String streetName;
  final String? streetType; // e.g., "Street", "Road", "Avenue"

  // Level 3: Building (optional - street is usually enough)
  final String? buildingNumber;
  final String? buildingName; // e.g., "Nile Tower", "Al-Rehab City"

  // Level 4: Details (optional)
  final String? floor;
  final String? apartmentNumber;
  final String? entrance;

  // Level 5: Extras (optional)
  final String? postalCode;
  final String? landmark; // e.g., "Near Carrefour", "Behind hospital"
  final String? additionalInfo; // Delivery instructions

  // Coordinates (always required - obtained via geocoding)
  final GeoPoint coordinates;

  // Metadata
  final String formattedAddress; // Full formatted address string
  final DateTime createdAt;

  StructuredAddress({
    required this.city,
    this.cityCode,
    required this.country,
    this.countryCode,
    required this.streetName,
    this.streetType,
    this.buildingNumber,
    this.buildingName,
    this.floor,
    this.apartmentNumber,
    this.entrance,
    this.postalCode,
    this.landmark,
    this.additionalInfo,
    required this.coordinates,
    required this.formattedAddress,
    required this.createdAt,
  });

  /// TIER 1: Public address (for browsing/discovery)
  /// Shows only: City, Country, Postal Code
  String toPublicAddress() {
    final parts = <String>[];
    parts.add(city);
    if (postalCode != null && postalCode!.isNotEmpty) {
      parts.add(postalCode!);
    }
    parts.add(country);
    return parts.join(', ');
  }

  /// TIER 2: Approximate address (for dish details before order)
  /// Shows: Street name, City, Country (NO building number)
  String toApproximateAddress() {
    final parts = <String>[];
    if (streetType != null && streetType!.isNotEmpty) {
      parts.add('$streetName $streetType');
    } else {
      parts.add(streetName);
    }
    parts.add(city);
    if (postalCode != null && postalCode!.isNotEmpty) {
      parts.add(postalCode!);
    }
    parts.add(country);
    return parts.join(', ');
  }

  /// TIER 3: Full exact address (after order confirmation)
  /// Shows everything including building number, apartment, floor
  String toFullAddress() {
    final parts = <String>[];

    // Building info
    if (buildingName != null && buildingName!.isNotEmpty) {
      parts.add(buildingName!);
    }
    if (buildingNumber != null && buildingNumber!.isNotEmpty) {
      parts.add(buildingNumber!);
    }

    // Street
    if (streetType != null && streetType!.isNotEmpty) {
      parts.add('$streetName $streetType');
    } else {
      parts.add(streetName);
    }

    // Apartment details
    if (apartmentNumber != null && apartmentNumber!.isNotEmpty) {
      if (floor != null && floor!.isNotEmpty) {
        parts.add('Apt $apartmentNumber, Floor $floor');
      } else {
        parts.add('Apt $apartmentNumber');
      }
    } else if (floor != null && floor!.isNotEmpty) {
      parts.add('Floor $floor');
    }

    // Entrance
    if (entrance != null && entrance!.isNotEmpty) {
      parts.add('Entrance: $entrance');
    }

    // City and postal
    parts.add(city);
    if (postalCode != null && postalCode!.isNotEmpty) {
      parts.add(postalCode!);
    }
    parts.add(country);

    // Landmark
    if (landmark != null && landmark!.isNotEmpty) {
      parts.add('(Near: $landmark)');
    }

    return parts.join(', ');
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'city': city,
      'cityCode': cityCode,
      'country': country,
      'countryCode': countryCode,
      'streetName': streetName,
      'streetType': streetType,
      'buildingNumber': buildingNumber,
      'buildingName': buildingName,
      'floor': floor,
      'apartmentNumber': apartmentNumber,
      'entrance': entrance,
      'postalCode': postalCode,
      'landmark': landmark,
      'additionalInfo': additionalInfo,
      'coordinates': coordinates,
      'formattedAddress': formattedAddress,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create from Firestore document
  factory StructuredAddress.fromFirestore(Map<String, dynamic> data) {
    // Handle coordinates safely
    GeoPoint coords;
    if (data['coordinates'] is GeoPoint) {
      coords = data['coordinates'] as GeoPoint;
    } else if (data['coordinates'] is Map) {
      final coordMap = data['coordinates'] as Map;
      final lat = (coordMap['latitude'] ?? coordMap['lat'] ?? 0.0) as double;
      final lng = (coordMap['longitude'] ?? coordMap['lng'] ?? 0.0) as double;
      coords = GeoPoint(lat, lng);
    } else {
      coords = const GeoPoint(0, 0);
    }

    // Handle timestamp
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    return StructuredAddress(
      city: data['city'] ?? '',
      cityCode: data['cityCode'],
      country: data['country'] ?? '',
      countryCode: data['countryCode'],
      streetName: data['streetName'] ?? '',
      streetType: data['streetType'],
      buildingNumber: data['buildingNumber'],
      buildingName: data['buildingName'],
      floor: data['floor'],
      apartmentNumber: data['apartmentNumber'],
      entrance: data['entrance'],
      postalCode: data['postalCode'],
      landmark: data['landmark'],
      additionalInfo: data['additionalInfo'],
      coordinates: coords,
      formattedAddress: data['formattedAddress'] ?? '',
      createdAt: createdAt,
    );
  }

  /// Create a copy with updated fields
  StructuredAddress copyWith({
    String? city,
    String? cityCode,
    String? country,
    String? countryCode,
    String? streetName,
    String? streetType,
    String? buildingNumber,
    String? buildingName,
    String? floor,
    String? apartmentNumber,
    String? entrance,
    String? postalCode,
    String? landmark,
    String? additionalInfo,
    GeoPoint? coordinates,
    String? formattedAddress,
    DateTime? createdAt,
  }) {
    return StructuredAddress(
      city: city ?? this.city,
      cityCode: cityCode ?? this.cityCode,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      streetName: streetName ?? this.streetName,
      streetType: streetType ?? this.streetType,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      buildingName: buildingName ?? this.buildingName,
      floor: floor ?? this.floor,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      entrance: entrance ?? this.entrance,
      postalCode: postalCode ?? this.postalCode,
      landmark: landmark ?? this.landmark,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      coordinates: coordinates ?? this.coordinates,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get obfuscated coordinates (adds 200-500m random offset for TIER 2)
  /// Uses seed to ensure consistency per user/dish combination
  GeoPoint getObfuscatedCoordinates({
    int minOffsetMeters = 200,
    int maxOffsetMeters = 500,
    String? seed,
  }) {
    if (seed != null && seed.isNotEmpty) {
      return LocationObfuscationService.obfuscateLocationWithSeed(
        coordinates,
        seed,
        minOffsetMeters: minOffsetMeters,
        maxOffsetMeters: maxOffsetMeters,
      );
    }

    return LocationObfuscationService.obfuscateLocation(
      coordinates,
      minOffsetMeters: minOffsetMeters,
      maxOffsetMeters: maxOffsetMeters,
    );
  }

  @override
  String toString() => formattedAddress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StructuredAddress &&
        other.city == city &&
        other.streetName == streetName &&
        other.buildingNumber == buildingNumber &&
        other.apartmentNumber == apartmentNumber &&
        other.coordinates.latitude == coordinates.latitude &&
        other.coordinates.longitude == coordinates.longitude;
  }

  @override
  int get hashCode =>
      city.hashCode ^
      streetName.hashCode ^
      buildingNumber.hashCode ^
      (apartmentNumber?.hashCode ?? 0) ^
      coordinates.latitude.hashCode ^
      coordinates.longitude.hashCode;
}
