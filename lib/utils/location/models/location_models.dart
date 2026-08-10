// ─────────────────────────────────────────
// Model: LocationModels
// Description: Structured location data classes with GeoPoint support.
// Contains: UserLocation, fromMap, toMap, coordinates
// ─────────────────────────────────────────

import 'dart:math';

class LocationData {
  final String? city;
  final String? postalCode;
  final String? country;
  final String? countryCode;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  const LocationData({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.city,
    this.postalCode,
    this.country,
    this.countryCode,
  });

  LocationData copyWith({
    String? city,
    String? postalCode,
    String? country,
    String? countryCode,
    String? formattedAddress,
    double? latitude,
    double? longitude,
  }) {
    return LocationData(
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() => {
        'city': city,
        'postalCode': postalCode,
        'country': country,
        'countryCode': countryCode,
        'formattedAddress': formattedAddress,
        'latitude': latitude,
        'longitude': longitude,
      }..removeWhere((_, v) => v == null);

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      city: map['city'] as String?,
      postalCode: map['postalCode'] as String?,
      country: map['country'] as String?,
      countryCode: map['countryCode'] as String?,
      formattedAddress: (map['formattedAddress'] ?? '') as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  static double haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * pi / 180.0;
}

class LocationSuggestion {
  final String id;
  final String title; // Primary label (city or formatted)
  final String subtitle; // Secondary label (country, admin area)
  final double latitude;
  final double longitude;
  final Map<String, dynamic> raw;

  const LocationSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.raw = const {},
  });
}
