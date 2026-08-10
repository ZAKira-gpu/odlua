// ─────────────────────────────────────────
// Service: LocationObfuscationService
// Description: Adds random offset to exact coordinates for privacy.
// Contains: obfuscate, deobfuscate, privacyRadius
// ─────────────────────────────────────────

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for location privacy and obfuscation
/// Adds random offset to coordinates for TIER 2 (approximate location display)
class LocationObfuscationService {
  static final Random _random = Random();

  /// Obfuscate location by adding random offset
  /// Default range: 200-500 meters
  /// This prevents exact location disclosure before order confirmation
  static GeoPoint obfuscateLocation(
    GeoPoint original, {
    int minOffsetMeters = 200,
    int maxOffsetMeters = 500,
  }) {
    // Generate random distance within range
    final distance = minOffsetMeters +
        _random.nextDouble() * (maxOffsetMeters - minOffsetMeters);

    // Generate random bearing (0-360 degrees)
    final bearing = _random.nextDouble() * 360;

    // Calculate new coordinates
    final newCoords = _addDistanceAndBearing(
      original.latitude,
      original.longitude,
      distance,
      bearing,
    );

    return GeoPoint(newCoords['latitude']!, newCoords['longitude']!);
  }

  /// Calculate new coordinates by adding distance and bearing
  /// Uses Haversine formula
  static Map<String, double> _addDistanceAndBearing(
    double lat,
    double lng,
    double distanceMeters,
    double bearingDegrees,
  ) {
    const earthRadiusKm = 6371.0;
    final distanceKm = distanceMeters / 1000.0;
    final bearingRadians = _degreesToRadians(bearingDegrees);
    final latRadians = _degreesToRadians(lat);
    final lngRadians = _degreesToRadians(lng);

    final newLatRadians = asin(
      sin(latRadians) * cos(distanceKm / earthRadiusKm) +
          cos(latRadians) *
              sin(distanceKm / earthRadiusKm) *
              cos(bearingRadians),
    );

    final newLngRadians = lngRadians +
        atan2(
          sin(bearingRadians) *
              sin(distanceKm / earthRadiusKm) *
              cos(latRadians),
          cos(distanceKm / earthRadiusKm) -
              sin(latRadians) * sin(newLatRadians),
        );

    return {
      'latitude': _radiansToDegrees(newLatRadians),
      'longitude': _radiansToDegrees(newLngRadians),
    };
  }

  /// Get approximate distance range string (for TIER 1 display)
  /// e.g., "< 1 km", "1-2 km", "2-5 km", "5-10 km", "> 10 km"
  static String getApproximateDistanceRange(double distanceKm) {
    if (distanceKm < 0.5) {
      return '< 500 m';
    } else if (distanceKm < 1) {
      return '< 1 km';
    } else if (distanceKm < 2) {
      return '1-2 km';
    } else if (distanceKm < 5) {
      return '2-5 km';
    } else if (distanceKm < 10) {
      return '5-10 km';
    } else if (distanceKm < 20) {
      return '10-20 km';
    } else {
      return '> 20 km';
    }
  }

  /// Calculate circle radius for map display
  /// For TIER 2, show a circle with this radius around obfuscated point
  static double getMapCircleRadius(int offsetMeters) {
    // Circle radius should be slightly larger than max offset
    // to give a reasonable area indication
    return offsetMeters * 1.2;
  }

  /// Check if two obfuscated points might be the same location
  /// Used for privacy checks - prevents reverse-engineering exact location
  static bool mightBeSameLocation(
    GeoPoint point1,
    GeoPoint point2, {
    double thresholdMeters = 1000,
  }) {
    final distance = _calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
    return distance <= thresholdMeters;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  /// Generate consistent obfuscation for the same location
  /// Uses seed based on location + user ID to ensure same obfuscation each time
  /// This prevents location from "jumping" on each page load
  static GeoPoint obfuscateLocationWithSeed(
    GeoPoint original,
    String seed, {
    int minOffsetMeters = 200,
    int maxOffsetMeters = 500,
  }) {
    // Create deterministic random generator from seed
    final seedHash = seed.hashCode.abs();
    final seededRandom = Random(seedHash);

    final distance = minOffsetMeters +
        seededRandom.nextDouble() * (maxOffsetMeters - minOffsetMeters);
    final bearing = seededRandom.nextDouble() * 360;

    final newCoords = _addDistanceAndBearing(
      original.latitude,
      original.longitude,
      distance,
      bearing,
    );

    return GeoPoint(newCoords['latitude']!, newCoords['longitude']!);
  }

  /// Validate that coordinates are within reasonable bounds
  static bool areValidCoordinates(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// Get privacy tier based on context
  /// Returns 1, 2, or 3 based on relationship between user and dish/order
  static int getPrivacyTier({
    required String currentUserId,
    required String dishChefId,
    String? orderId,
    bool hasConfirmedOrder = false,
  }) {
    // TIER 3: Full exact address
    // Only after order is confirmed and user is either buyer or chef
    if (hasConfirmedOrder && orderId != null) {
      return 3;
    }

    // TIER 2: Approximate location (street + fuzzy map)
    // User is viewing dish details but hasn't ordered yet
    if (currentUserId.isNotEmpty) {
      return 2;
    }

    // TIER 1: Public location (city + distance range only)
    // For browsing, not logged in, or general discovery
    return 1;
  }
}
