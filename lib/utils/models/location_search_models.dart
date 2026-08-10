// ─────────────────────────────────────────
// Model: LocationSearchModels
// Description: Data classes for Geoapify autocomplete results.
// Contains: LocationSuggestion, fromJson
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

/// Result from city search autocomplete
class CityResult {
  final String name;
  final String?
      cityCode; // Normalized code for filtering (e.g., "cairo", "alex")
  final String country;
  final String? countryCode; // e.g., "EG", "SA", "AE"
  final String? postalCode;
  final GeoPoint coordinates;
  final String? state; // Province/Governorate
  final String formattedAddress;

  CityResult({
    required this.name,
    this.cityCode,
    required this.country,
    this.countryCode,
    this.postalCode,
    required this.coordinates,
    this.state,
    required this.formattedAddress,
  });

  /// Create from Geoapify API response
  factory CityResult.fromGeoapify(Map<String, dynamic> json) {
    final properties = json['properties'] ?? {};
    final geometry = json['geometry'] ?? {};
    final coords = geometry['coordinates'] as List?;

    return CityResult(
      name: properties['city'] ??
          properties['municipality'] ??
          properties['town'] ??
          properties['village'] ??
          '',
      cityCode: _normalizeCityCode(
        properties['city'] ??
            properties['municipality'] ??
            properties['town'] ??
            '',
      ),
      country: properties['country'] ?? '',
      countryCode: (properties['country_code'] ?? '').toUpperCase(),
      postalCode: properties['postcode'],
      coordinates: GeoPoint(
        (coords != null && coords.length >= 2
                ? coords[1]
                : properties['lat'] ?? 0.0)
            .toDouble(),
        (coords != null && coords.length >= 2
                ? coords[0]
                : properties['lon'] ?? 0.0)
            .toDouble(),
      ),
      state: properties['state'] ?? properties['county'],
      formattedAddress: properties['formatted'] ?? '',
    );
  }

  /// Create from Google Places API response
  factory CityResult.fromGooglePlaces(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};
    final addressComponents = json['address_components'] as List? ?? [];

    String? city;
    String? country;
    String? countryCode;
    String? postalCode;
    String? state;

    for (final component in addressComponents) {
      final types = (component['types'] as List? ?? []).cast<String>();
      if (types.contains('locality')) {
        city = component['long_name'];
      } else if (types.contains('administrative_area_level_1')) {
        state = component['long_name'];
      } else if (types.contains('country')) {
        country = component['long_name'];
        countryCode = component['short_name'];
      } else if (types.contains('postal_code')) {
        postalCode = component['long_name'];
      }
    }

    return CityResult(
      name: city ?? json['name'] ?? '',
      cityCode: _normalizeCityCode(city ?? ''),
      country: country ?? '',
      countryCode: countryCode,
      postalCode: postalCode,
      coordinates: GeoPoint(
        (location['lat'] ?? 0.0).toDouble(),
        (location['lng'] ?? 0.0).toDouble(),
      ),
      state: state,
      formattedAddress: json['formatted_address'] ?? '',
    );
  }

  /// Normalize city name to lowercase code for filtering
  static String _normalizeCityCode(String city) {
    return city.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  String toString() => formattedAddress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CityResult &&
        other.name == name &&
        other.country == country &&
        other.coordinates.latitude == coordinates.latitude &&
        other.coordinates.longitude == coordinates.longitude;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      country.hashCode ^
      coordinates.latitude.hashCode ^
      coordinates.longitude.hashCode;
}

/// Result from street search autocomplete
class StreetResult {
  final String name;
  final String? type; // e.g., "Street", "Road", "Avenue", "Boulevard"
  final String city;
  final String? cityCode;
  final String? postalCode;
  final GeoPoint coordinates;
  final String formattedAddress;

  StreetResult({
    required this.name,
    this.type,
    required this.city,
    this.cityCode,
    this.postalCode,
    required this.coordinates,
    required this.formattedAddress,
  });

  /// Create from Geoapify API response
  factory StreetResult.fromGeoapify(Map<String, dynamic> json) {
    final properties = json['properties'] ?? {};
    final geometry = json['geometry'] ?? {};
    final coords = geometry['coordinates'] as List?;

    return StreetResult(
      name: properties['street'] ?? properties['name'] ?? '',
      type: _extractStreetType(properties['street'] ?? ''),
      city: properties['city'] ??
          properties['municipality'] ??
          properties['town'] ??
          '',
      cityCode: CityResult._normalizeCityCode(
        properties['city'] ?? properties['municipality'] ?? '',
      ),
      postalCode: properties['postcode'],
      coordinates: GeoPoint(
        (coords != null && coords.length >= 2
                ? coords[1]
                : properties['lat'] ?? 0.0)
            .toDouble(),
        (coords != null && coords.length >= 2
                ? coords[0]
                : properties['lon'] ?? 0.0)
            .toDouble(),
      ),
      formattedAddress: properties['formatted'] ?? '',
    );
  }

  /// Create from Google Places API response
  factory StreetResult.fromGooglePlaces(Map<String, dynamic> json) {
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};
    final addressComponents = json['address_components'] as List? ?? [];

    String? street;
    String? city;
    String? postalCode;

    for (final component in addressComponents) {
      final types = (component['types'] as List? ?? []).cast<String>();
      if (types.contains('route')) {
        street = component['long_name'];
      } else if (types.contains('locality')) {
        city = component['long_name'];
      } else if (types.contains('postal_code')) {
        postalCode = component['long_name'];
      }
    }

    return StreetResult(
      name: street ?? json['name'] ?? '',
      type: _extractStreetType(street ?? ''),
      city: city ?? '',
      cityCode: CityResult._normalizeCityCode(city ?? ''),
      postalCode: postalCode,
      coordinates: GeoPoint(
        (location['lat'] ?? 0.0).toDouble(),
        (location['lng'] ?? 0.0).toDouble(),
      ),
      formattedAddress: json['formatted_address'] ?? '',
    );
  }

  /// Extract street type from street name (e.g., "Main Street" -> "Street")
  static String? _extractStreetType(String streetName) {
    final types = [
      'Street',
      'Road',
      'Avenue',
      'Boulevard',
      'Lane',
      'Drive',
      'Court',
      'Place',
      'Square',
      'Terrace',
      'Way',
      'Alley',
    ];

    for (final type in types) {
      if (streetName.toLowerCase().contains(type.toLowerCase())) {
        return type;
      }
    }
    return null;
  }

  /// Get full street name with type
  String get fullName {
    if (type != null && !name.toLowerCase().contains(type!.toLowerCase())) {
      return '$name $type';
    }
    return name;
  }

  @override
  String toString() => fullName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreetResult &&
        other.name == name &&
        other.city == city &&
        other.coordinates.latitude == coordinates.latitude &&
        other.coordinates.longitude == coordinates.longitude;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      city.hashCode ^
      coordinates.latitude.hashCode ^
      coordinates.longitude.hashCode;
}

/// Building validation result
class BuildingValidation {
  final bool isValid;
  final String? errorMessage;
  final GeoPoint? coordinates;
  final String? formattedAddress;

  BuildingValidation({
    required this.isValid,
    this.errorMessage,
    this.coordinates,
    this.formattedAddress,
  });

  factory BuildingValidation.valid({
    required GeoPoint coordinates,
    required String formattedAddress,
  }) {
    return BuildingValidation(
      isValid: true,
      coordinates: coordinates,
      formattedAddress: formattedAddress,
    );
  }

  factory BuildingValidation.invalid(String errorMessage) {
    return BuildingValidation(
      isValid: false,
      errorMessage: errorMessage,
    );
  }
}
