// ─────────────────────────────────────────
// Service: LocationServices
// Description: GPS permission handling and current-position fetch.
// Contains: requestPermission, getCurrentLocation
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

enum LocationPermissionStatus {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Location service that provides real-time GPS location for dish distance calculations.
/// Uses the device's current GPS position (not saved profile location) so dishes
/// are always sorted by proximity to the user's actual current location.
///
/// This is a singleton to ensure all widgets share the same GPS stream and location data.
class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Current GPS position stored as Map for compatibility
  Map<String, dynamic>? _currentPosition;
  bool _isLoading = false;
  String _locationError = '';
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.unknown;
  bool _isLocationEnabled = true; // User preference for using location
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastLocationUpdate;
  bool _isInitialized = false;

  // Multiple listeners support
  final List<VoidCallback> _listeners = [];

  /// Legacy single listener - kept for backward compatibility
  /// Prefer using addListener/removeListener for new code
  VoidCallback? onStateChanged;

  Map<String, dynamic>? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get hasLocation =>
      _currentPosition != null &&
      _currentPosition!['latitude'] != null &&
      _currentPosition!['longitude'] != null &&
      _currentPosition!['latitude'] != 0.0 &&
      _currentPosition!['longitude'] != 0.0;
  String get locationError => _locationError;
  LocationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isLocationEnabled => _isLocationEnabled;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  bool get canRequestLocation =>
      _permissionStatus != LocationPermissionStatus.deniedForever;

  // SharedPreferences keys
  static const String _prefKeyLocationEnabled = 'location_enabled';
  static const String _prefKeyLastLat = 'last_latitude';
  static const String _prefKeyLastLng = 'last_longitude';
  static const String _prefKeyLastUpdate = 'last_location_update';

  /// Add a listener to be notified when location changes
  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Remove a listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _loadPreferences();
    if (_isLocationEnabled) {
      await getCurrentLocation();
    }
  }

  /// Dispose of location stream subscription
  /// Note: For singleton, this should rarely be called
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _listeners.clear();
    _isInitialized = false;
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLocationEnabled = prefs.getBool(_prefKeyLocationEnabled) ?? true;

      // Load last known location as fallback (used until fresh GPS is obtained)
      final lastLat = prefs.getDouble(_prefKeyLastLat);
      final lastLng = prefs.getDouble(_prefKeyLastLng);
      final lastUpdateStr = prefs.getString(_prefKeyLastUpdate);

      if (lastLat != null &&
          lastLng != null &&
          lastLat != 0.0 &&
          lastLng != 0.0) {
        _currentPosition = {
          'latitude': lastLat,
          'longitude': lastLng,
          'timestamp': lastUpdateStr ?? DateTime.now().toIso8601String(),
          'isStale': true, // Mark as stale until we get fresh GPS
        };

        if (lastUpdateStr != null) {
          _lastLocationUpdate = DateTime.tryParse(lastUpdateStr);
        }
      }
    } catch (e) {
      DebugHelper.logError('Error loading location preferences: $e');
    }
  }

  /// Save current location to preferences for quick startup next time
  Future<void> _saveLocationToPrefs(double lat, double lng) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeyLastLat, lat);
      await prefs.setDouble(_prefKeyLastLng, lng);
      await prefs.setString(
          _prefKeyLastUpdate, DateTime.now().toIso8601String());
    } catch (e) {
      DebugHelper.logError('Error saving location preferences: $e');
    }
  }

  Future<void> setLocationEnabled(bool enabled) async {
    _isLocationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyLocationEnabled, enabled);

    if (enabled) {
      await getCurrentLocation();
      _startLocationUpdates();
    } else {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _currentPosition = null;
    }
    _notifyListeners();
  }

  /// Start listening for location updates in the background
  void _startLocationUpdates() {
    if (!_isLocationEnabled) return;

    // Cancel existing subscription
    _positionSubscription?.cancel();

    // Set up location settings for background updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium, // Balance between accuracy and battery
      distanceFilter: 500, // Only update if moved 500 meters
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _updatePosition(position);
        },
        onError: (error) {
          DebugHelper.logError('Location stream error: $error');
          // Don't clear position on stream error, keep last known
        },
      );
    } catch (e) {
      DebugHelper.logError('Error starting location updates: $e');
    }
  }

  /// Update position from GPS reading
  void _updatePosition(Position position, {bool isFromCache = false}) {
    _currentPosition = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'altitude': position.altitude,
      'speed': position.speed,
      'timestamp': position.timestamp.toIso8601String(),
      'isStale': isFromCache,
    };
    _lastLocationUpdate = DateTime.now();
    _locationError = '';

    // Save to preferences for quick startup next time
    _saveLocationToPrefs(position.latitude, position.longitude);

    _notifyListeners();
  }

  /// Get fresh GPS position in background (doesn't block UI)
  Future<void> _getFreshPositionInBackground() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      _updatePosition(position);
      _startLocationUpdates();
    } catch (e) {
      DebugHelper.logError('Background location refresh failed: $e');
      // Keep using cached position, start updates anyway
      _startLocationUpdates();
    }
  }

  void _notifyListeners() {
    // Notify legacy single listener
    onStateChanged?.call();

    // Notify all registered listeners
    for (final listener in List.from(_listeners)) {
      try {
        listener();
      } catch (e) {
        DebugHelper.logError('Error notifying location listener: $e');
      }
    }
  }

  Future<void> refreshLocation() async {
    await getCurrentLocation();
  }

  Future<LocationPermissionStatus> checkPermissionStatus() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionStatus = LocationPermissionStatus.serviceDisabled;
        return _permissionStatus;
      }

      // Check permission status
      final permission = await Geolocator.checkPermission();
      _permissionStatus = _mapGeolocatorPermission(permission);
      return _permissionStatus;
    } catch (e) {
      DebugHelper.logError('Error checking permission status: $e');
      return LocationPermissionStatus.unknown;
    }
  }

  /// Map Geolocator permission to our enum
  LocationPermissionStatus _mapGeolocatorPermission(
      LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  Future<bool> requestPermission() async {
    try {
      // First check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionStatus = LocationPermissionStatus.serviceDisabled;
        _locationError = 'location_services_disabled'.tr();
        return false;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _permissionStatus = LocationPermissionStatus.denied;
        _locationError = 'location_permission_denied'.tr();
        return false;
      } else if (permission == LocationPermission.deniedForever) {
        _permissionStatus = LocationPermissionStatus.deniedForever;
        _locationError = 'location_permission_permanently_denied'.tr();
        return false;
      }

      _permissionStatus = LocationPermissionStatus.granted;
      return true;
    } catch (e) {
      DebugHelper.logError('Error requesting permission: $e');
      return false;
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (e) {
      DebugHelper.logError('Error opening location settings: $e');
    }
  }

  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      DebugHelper.logError('Error opening app settings: $e');
    }
  }

  /// Fetches the user's GPS position using a fast-path / slow-path strategy.
  ///
  /// Fast path: returns instantly from [Geolocator.getLastKnownPosition],
  /// then refreshes in background via [_getFreshPositionInBackground].
  /// Slow path (no cache): calls [Geolocator.getCurrentPosition] with an 8 s
  /// timeout, then starts continuous 500 m distance-filter updates.
  ///
  /// [silent] = true suppresses loading state (used for background refreshes).
  Future<void> getCurrentLocation({bool silent = false}) async {
    if (!_isLocationEnabled) {
      return;
    }

    try {
      if (!silent) {
        _isLoading = true;
        _locationError = '';
        _notifyListeners();
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionStatus = LocationPermissionStatus.serviceDisabled;
        _locationError = 'location_services_disabled'.tr();
        _isLoading = false;
        _notifyListeners();
        return;
      }

      // Check and request permission if needed
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _permissionStatus = LocationPermissionStatus.denied;
          _locationError = 'location_permission_required'.tr();
          _isLoading = false;
          _notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionStatus = LocationPermissionStatus.deniedForever;
        _locationError = 'location_permission_permanently_denied'.tr();
        _isLoading = false;
        _notifyListeners();
        return;
      }

      _permissionStatus = LocationPermissionStatus.granted;

      // FAST PATH: Try to get last known position first (instant)
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _updatePosition(lastKnown, isFromCache: true);
          _isLoading = false;
          _notifyListeners();

          // Continue to get fresh position in background
          _getFreshPositionInBackground();
          return;
        }
      } catch (e) {
        DebugHelper.logError('Could not get last known position: $e');
      }

      // SLOW PATH: Get current position from GPS (only if no cached position)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Faster than high accuracy
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Location request timed out');
        },
      );

      // Update position
      _updatePosition(position);

      // Start continuous updates
      _startLocationUpdates();

      _isLoading = false;
      _notifyListeners();
    } on TimeoutException {
      _isLoading = false;
      _locationError = 'location_timeout'.tr();
      _notifyListeners();
      // Fall back to cached position if available
      _loadCachedPositionFallback();
    } catch (e) {
      _isLoading = false;
      _locationError = 'failed_to_get_location'.tr();
      DebugHelper.logError('Location error: $e');
      _notifyListeners();
      // Fall back to cached position if available
      _loadCachedPositionFallback();
    }
  }

  /// Load cached position as fallback when GPS fails
  Future<void> _loadCachedPositionFallback() async {
    if (_currentPosition != null && _currentPosition!['isStale'] != true) {
      return; // Already have a fresh position
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefKeyLastLat);
      final lng = prefs.getDouble(_prefKeyLastLng);

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        _currentPosition = {
          'latitude': lat,
          'longitude': lng,
          'timestamp': DateTime.now().toIso8601String(),
          'isStale': true,
        };
        _notifyListeners();
      }
    } catch (e) {
      DebugHelper.logError('Error loading cached position fallback: $e');
    }
  }

  String getPermissionStatusMessage() {
    switch (_permissionStatus) {
      case LocationPermissionStatus.granted:
        return 'location_permission_granted'.tr();
      case LocationPermissionStatus.denied:
        return 'location_permission_denied'.tr();
      case LocationPermissionStatus.deniedForever:
        return 'location_permission_permanently_denied'.tr();
      case LocationPermissionStatus.serviceDisabled:
        return 'location_services_disabled'.tr();
      default:
        return 'location_status_unknown'.tr();
    }
  }

  /// Calculate distance between two coordinates in kilometers
  /// Uses Geolocator's built-in distance calculation (Vincenty formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    try {
      // Geolocator.distanceBetween returns distance in meters
      final distanceInMeters =
          Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      return distanceInMeters / 1000; // Convert to kilometers
    } catch (e) {
      DebugHelper.logError('Error calculating distance: $e');
      // Fallback to manual Haversine calculation
      return _calculateDistanceHaversine(lat1, lon1, lat2, lon2);
    }
  }

  /// Fallback Haversine formula for distance calculation
  double _calculateDistanceHaversine(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  String formatDistance(double distance) {
    if (distance == -1) return 'unknown'.tr();
    if (distance < 0.1) return '${(distance * 1000).toStringAsFixed(0)} m';
    if (distance < 1) return '${(distance * 1000).toStringAsFixed(0)} m';
    return '${distance.toStringAsFixed(1)} km';
  }

  /// Get distance from current position to a target location
  /// Returns -1 if current position is not available
  double getDistanceToLocation(double targetLat, double targetLng) {
    if (_currentPosition == null) return -1;

    final lat = _currentPosition!['latitude'];
    final lng = _currentPosition!['longitude'];

    if (lat == null || lng == null) return -1;
    if (lat is! num || lng is! num) return -1;
    if (lat == 0.0 && lng == 0.0) return -1;

    return calculateDistance(
        lat.toDouble(), lng.toDouble(), targetLat, targetLng);
  }

  /// Check if current position is fresh (not stale/cached)
  bool get hasValidFreshLocation {
    if (_currentPosition == null) return false;
    if (_currentPosition!['isStale'] == true) return false;

    final lat = _currentPosition!['latitude'];
    final lng = _currentPosition!['longitude'];

    if (lat == null || lng == null) return false;
    if (lat is! num || lng is! num) return false;
    if (lat == 0.0 && lng == 0.0) return false;

    return true;
  }
}
