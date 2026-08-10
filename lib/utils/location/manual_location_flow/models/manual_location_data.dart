// ─────────────────────────────────────────
// Model: ManualLocationData
// Description: Data class holding the user selections from the manual flow.
// Contains: continent, country, city, street
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

/// Clean location data model for the manual location flow
/// Collects ONLY: Continent, Country, City, Street - with validated coordinates
class ManualLocationData {
  final String continent;
  final String country;
  final String countryCode;
  final String city;
  final String street;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final DateTime createdAt;

  const ManualLocationData({
    required this.continent,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.street,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.createdAt,
  });

  /// Check if coordinates are valid (non-zero)
  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  /// Get display address (City, Country)
  String get displayAddress => '$city, $country';

  /// Get full address (Street, City, Country)
  String get fullAddress => '$street, $city, $country';

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() => {
        'continent': continent,
        'country': country,
        'countryCode': countryCode,
        'city': city,
        'street': street,
        'latitude': latitude,
        'longitude': longitude,
        'formattedAddress': formattedAddress,
        'coordinates': GeoPoint(latitude, longitude),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'manual_selection',
      };

  /// Create from Firestore document
  factory ManualLocationData.fromFirestore(Map<String, dynamic> data) {
    double lat = 0.0;
    double lng = 0.0;

    // Handle coordinates field (GeoPoint or nested map)
    if (data['coordinates'] is GeoPoint) {
      lat = (data['coordinates'] as GeoPoint).latitude;
      lng = (data['coordinates'] as GeoPoint).longitude;
    } else {
      lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
      lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    }

    return ManualLocationData(
      continent: data['continent']?.toString() ?? '',
      country: data['country']?.toString() ?? '',
      countryCode: data['countryCode']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      street: data['street']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      formattedAddress: data['formattedAddress']?.toString() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Copy with modifications
  ManualLocationData copyWith({
    String? continent,
    String? country,
    String? countryCode,
    String? city,
    String? street,
    double? latitude,
    double? longitude,
    String? formattedAddress,
  }) {
    return ManualLocationData(
      continent: continent ?? this.continent,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      street: street ?? this.street,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'ManualLocationData(continent: $continent, country: $country, city: $city, street: $street, lat: $latitude, lng: $longitude)';
}

/// Continent definition with countries
class ContinentData {
  final String name;
  final String emoji;
  final List<CountryData> countries;

  const ContinentData({
    required this.name,
    required this.emoji,
    required this.countries,
  });
}

/// Country definition
class CountryData {
  final String name;
  final String code;
  final String flag;
  final String dialCode;

  const CountryData({
    required this.name,
    required this.code,
    required this.flag,
    this.dialCode = '',
  });
}

/// City validation result
class CityValidationResult {
  final bool isValid;
  final String cityName;
  final double latitude;
  final double longitude;
  final String? errorMessage;

  const CityValidationResult({
    required this.isValid,
    required this.cityName,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.errorMessage,
  });

  factory CityValidationResult.invalid(String error) => CityValidationResult(
        isValid: false,
        cityName: '',
        errorMessage: error,
      );

  factory CityValidationResult.valid({
    required String cityName,
    required double latitude,
    required double longitude,
  }) =>
      CityValidationResult(
        isValid: true,
        cityName: cityName,
        latitude: latitude,
        longitude: longitude,
      );
}

/// Street validation result
class StreetValidationResult {
  final bool isValid;
  final String streetName;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String? errorMessage;

  const StreetValidationResult({
    required this.isValid,
    required this.streetName,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.formattedAddress = '',
    this.errorMessage,
  });

  factory StreetValidationResult.invalid(String error) =>
      StreetValidationResult(
        isValid: false,
        streetName: '',
        errorMessage: error,
      );

  factory StreetValidationResult.valid({
    required String streetName,
    required double latitude,
    required double longitude,
    required String formattedAddress,
  }) =>
      StreetValidationResult(
        isValid: true,
        streetName: streetName,
        latitude: latitude,
        longitude: longitude,
        formattedAddress: formattedAddress,
      );
}
