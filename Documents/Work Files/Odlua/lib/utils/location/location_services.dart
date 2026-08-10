import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';

class LocationService {
  Position? _currentPosition;
  bool _isLoading = false;
  String _locationError = '';
  
  VoidCallback? onStateChanged;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get hasLocation => _currentPosition != null;
  String get locationError => _locationError;

  void _notifyListeners() {
    onStateChanged?.call();
  }

  Future<void> refreshLocation() async {
    await getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _locationError = '';
      _notifyListeners();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError = 'Location services are disabled';
        _isLoading = false;
        _notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationError = 'Location permission denied';
          _isLoading = false;
          _notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationError = 'Location permission permanently denied';
        _isLoading = false;
        _notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 10));

      _currentPosition = position;
      _isLoading = false;
      _notifyListeners();

    } catch (e) {
      _isLoading = false;
      _locationError = 'Failed to get location: $e';
      _notifyListeners();
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;

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
}