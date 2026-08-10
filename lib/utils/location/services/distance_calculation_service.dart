// ─────────────────────────────────────────
// Service: DistanceCalculationService
// Description: Haversine distance calculations between coordinates.
// Contains: calculateDistance, isWithinRadius
// ─────────────────────────────────────────

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for distance calculations and delivery zone validation
class DistanceCalculationService {
  // Constants for travel time estimation
  static const double _avgWalkingSpeedKmH = 5.0;
  static const double _avgCyclingSpeedKmH = 15.0;
  static const double _avgDrivingSpeedKmH = 30.0; // Urban speed
  static const double _avgPublicTransportSpeedKmH = 20.0;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
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

  /// Calculate distance from GeoPoint objects
  static double calculateDistanceFromGeoPoints(
    GeoPoint point1,
    GeoPoint point2,
  ) {
    return calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Estimate travel time in minutes based on distance and transport mode
  static double estimateTravelTime(
    double distanceKm, {
    String transportMode = 'driving',
  }) {
    double speedKmH;

    switch (transportMode.toLowerCase()) {
      case 'walking':
        speedKmH = _avgWalkingSpeedKmH;
        break;
      case 'cycling':
      case 'bicycle':
        speedKmH = _avgCyclingSpeedKmH;
        break;
      case 'public_transport':
      case 'transit':
        speedKmH = _avgPublicTransportSpeedKmH;
        break;
      case 'driving':
      case 'car':
      default:
        speedKmH = _avgDrivingSpeedKmH;
        break;
    }

    // Add 10% buffer for real-world conditions (traffic, stops, etc.)
    final timeHours = (distanceKm / speedKmH) * 1.1;
    return timeHours * 60; // Convert to minutes
  }

  /// Get formatted distance string
  static String getFormattedDistance(double distanceKm) {
    if (distanceKm < 0.1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    } else if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.toStringAsFixed(0)} km';
    }
  }

  /// Get formatted travel time string
  static String getFormattedTravelTime(double minutes) {
    if (minutes < 1) {
      return '< 1 min';
    } else if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = (minutes % 60).toStringAsFixed(0);
      if (remainingMinutes == '0') {
        return '$hours h';
      }
      return '${hours}h ${remainingMinutes}min';
    }
  }

  /// Validate if delivery is feasible based on distance
  /// Returns true if within acceptable delivery range
  static bool isDeliveryFeasible(
    double distanceKm, {
    double maxDeliveryDistanceKm = 50.0,
  }) {
    return distanceKm > 0 && distanceKm <= maxDeliveryDistanceKm;
  }

  /// Get delivery feasibility message
  static DeliveryFeasibility checkDeliveryFeasibility(
    double distanceKm, {
    double maxDeliveryDistanceKm = 50.0,
    double optimalDistanceKm = 10.0,
  }) {
    if (distanceKm <= 0) {
      return DeliveryFeasibility(
        isFeasible: false,
        message: 'Unable to calculate distance',
        category: 'error',
      );
    }

    if (distanceKm <= optimalDistanceKm) {
      return DeliveryFeasibility(
        isFeasible: true,
        message: 'Great! This dish is nearby',
        category: 'optimal',
        estimatedTime: estimateTravelTime(distanceKm),
      );
    }

    if (distanceKm <= maxDeliveryDistanceKm) {
      return DeliveryFeasibility(
        isFeasible: true,
        message: 'Delivery available (longer distance)',
        category: 'acceptable',
        estimatedTime: estimateTravelTime(distanceKm),
      );
    }

    return DeliveryFeasibility(
      isFeasible: false,
      message: 'Too far for delivery (${getFormattedDistance(distanceKm)})',
      category: 'too_far',
    );
  }

  /// Sort dishes by distance from user location
  static List<T> sortByDistance<T>(
    List<T> items,
    double userLat,
    double userLng,
    double Function(T) getLatitude,
    double Function(T) getLongitude,
  ) {
    final itemsWithDistance = items.map((item) {
      final distance = calculateDistance(
        userLat,
        userLng,
        getLatitude(item),
        getLongitude(item),
      );
      return {'item': item, 'distance': distance};
    }).toList();

    itemsWithDistance.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    return itemsWithDistance.map((e) => e['item'] as T).toList();
  }

  /// Filter items by maximum distance
  static List<T> filterByMaxDistance<T>(
    List<T> items,
    double userLat,
    double userLng,
    double maxDistanceKm,
    double Function(T) getLatitude,
    double Function(T) getLongitude,
  ) {
    return items.where((item) {
      final distance = calculateDistance(
        userLat,
        userLng,
        getLatitude(item),
        getLongitude(item),
      );
      return distance <= maxDistanceKm;
    }).toList();
  }

  /// Check if location is within a circular zone
  static bool isWithinZone(
    GeoPoint location,
    GeoPoint zoneCenter,
    double zoneRadiusKm,
  ) {
    final distance = calculateDistanceFromGeoPoints(location, zoneCenter);
    return distance <= zoneRadiusKm;
  }

  /// Calculate bearing (direction) from point1 to point2
  /// Returns bearing in degrees (0-360)
  static double calculateBearing(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLng = _degreesToRadians(lng2 - lng1);
    final lat1Rad = _degreesToRadians(lat1);
    final lat2Rad = _degreesToRadians(lat2);

    final y = sin(dLng) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLng);

    final bearingRad = atan2(y, x);
    final bearingDeg = _radiansToDegrees(bearingRad);

    return (bearingDeg + 360) % 360; // Normalize to 0-360
  }

  /// Get compass direction from bearing
  /// e.g., "North", "Northeast", "East", etc.
  static String getCompassDirection(double bearing) {
    const directions = [
      'North',
      'Northeast',
      'East',
      'Southeast',
      'South',
      'Southwest',
      'West',
      'Northwest',
    ];

    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  /// Get distance color for UI (green for close, yellow for medium, red for far)
  static String getDistanceColor(double distanceKm) {
    if (distanceKm < 2) {
      return '#4CAF50'; // Green
    } else if (distanceKm < 10) {
      return '#FF9800'; // Orange
    } else {
      return '#F44336'; // Red
    }
  }

  /// Get distance icon for UI
  static String getDistanceIcon(double distanceKm) {
    if (distanceKm < 2) {
      return '📍'; // Pin
    } else if (distanceKm < 10) {
      return '🚗'; // Car
    } else {
      return '🚙'; // Car with distance
    }
  }
}

/// Delivery feasibility result
class DeliveryFeasibility {
  final bool isFeasible;
  final String message;
  final String category; // 'optimal', 'acceptable', 'too_far', 'error'
  final double? estimatedTime; // in minutes

  DeliveryFeasibility({
    required this.isFeasible,
    required this.message,
    required this.category,
    this.estimatedTime,
  });

  String get estimatedTimeFormatted {
    if (estimatedTime == null) return '';
    return DistanceCalculationService.getFormattedTravelTime(estimatedTime!);
  }
}
