// ─────────────────────────────────────────
// Service: LocationValidationService
// Description: Validates manual location inputs against world data.
// Contains: validateCountry, validateCity
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manual_location_data.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Service for validating and geocoding cities and streets
/// Uses Geoapify for reliable global geocoding with fallback to Google Places
class LocationValidationService {
  final String _geoapifyKey;
  final String _googlePlacesKey;
  final Duration timeout;

  LocationValidationService({
    required String geoapifyKey,
    required String googlePlacesKey,
    this.timeout = const Duration(seconds: 8),
  })  : _geoapifyKey = geoapifyKey,
        _googlePlacesKey = googlePlacesKey;

  // ═══════════════════════════════════════════════════════════════════════════
  // CITY VALIDATION & AUTOCOMPLETE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Search for cities in a specific country
  /// Returns list of city suggestions with coordinates
  Future<List<CitySuggestion>> searchCities(
    String query, {
    required String countryCode,
  }) async {
    if (query.trim().length < 2) return [];

    try {
      // Try Geoapify first (more reliable for global coverage)
      final results = await _searchCitiesGeoapify(query, countryCode);
      if (results.isNotEmpty) return results;

      // Fallback to Google Places
      return await _searchCitiesGoogle(query, countryCode);
    } catch (e) {
      DebugHelper.logWarning('City search error: $e');
      return [];
    }
  }

  Future<List<CitySuggestion>> _searchCitiesGeoapify(
    String query,
    String countryCode,
  ) async {
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': query,
      'type': 'city',
      'filter': 'countrycode:${countryCode.toLowerCase()}',
      'format': 'json',
      'apiKey': _geoapifyKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];

    return results
        .map((r) {
          final props = r as Map<String, dynamic>;
          return CitySuggestion(
            name: props['city'] ?? props['name'] ?? '',
            fullName: props['formatted'] ?? '',
            latitude: (props['lat'] as num?)?.toDouble() ?? 0.0,
            longitude: (props['lon'] as num?)?.toDouble() ?? 0.0,
            countryCode: countryCode,
          );
        })
        .where((c) => c.name.isNotEmpty && c.hasValidCoordinates)
        .toList();
  }

  Future<List<CitySuggestion>> _searchCitiesGoogle(
    String query,
    String countryCode,
  ) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': query,
      'types': '(cities)',
      'components': 'country:$countryCode',
      'key': _googlePlacesKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final predictions = (data['predictions'] as List?) ?? [];

    // For Google, we need to fetch details for each to get coordinates
    final results = <CitySuggestion>[];
    for (final pred in predictions.take(5)) {
      final placeId = pred['place_id']?.toString();
      if (placeId == null) continue;

      final details = await _getGooglePlaceDetails(placeId);
      if (details != null) {
        results.add(details);
      }
    }

    return results;
  }

  Future<CitySuggestion?> _getGooglePlaceDetails(String placeId) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'geometry,address_components,formatted_address,name',
      'key': _googlePlacesKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    String? countryCode;
    for (final comp in (result['address_components'] as List?) ?? []) {
      final types = (comp['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('country')) {
        countryCode = comp['short_name'];
        break;
      }
    }

    return CitySuggestion(
      name: result['name']?.toString() ?? '',
      fullName: result['formatted_address']?.toString() ?? '',
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      countryCode: countryCode ?? '',
    );
  }

  /// Validate a city name and get coordinates
  Future<CityValidationResult> validateCity(
    String cityName, {
    required String countryCode,
  }) async {
    if (cityName.trim().isEmpty) {
      return CityValidationResult.invalid('City name is required');
    }

    try {
      final results = await searchCities(cityName, countryCode: countryCode);

      // Find exact or close match
      final exactMatch = results.firstWhere(
        (r) => r.name.toLowerCase() == cityName.toLowerCase(),
        orElse: () =>
            results.isNotEmpty ? results.first : CitySuggestion.empty(),
      );

      if (!exactMatch.hasValidCoordinates) {
        return CityValidationResult.invalid('Could not find city "$cityName"');
      }

      return CityValidationResult.valid(
        cityName: exactMatch.name,
        latitude: exactMatch.latitude,
        longitude: exactMatch.longitude,
      );
    } catch (e) {
      return CityValidationResult.invalid('Error validating city: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREET VALIDATION & AUTOCOMPLETE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Search for streets in a specific city
  /// Returns list of street suggestions with coordinates
  Future<List<StreetSuggestion>> searchStreets(
    String query, {
    required String city,
    required String countryCode,
    required double cityLat,
    required double cityLng,
  }) async {
    if (query.trim().length < 2) return [];

    try {
      // Try Geoapify first with bias toward city center
      final results = await _searchStreetsGeoapify(
        query,
        city,
        countryCode,
        cityLat,
        cityLng,
      );
      if (results.isNotEmpty) return results;

      // Fallback to Google Places
      return await _searchStreetsGoogle(
          query, city, countryCode, cityLat, cityLng);
    } catch (e) {
      DebugHelper.logWarning('Street search error: $e');
      return [];
    }
  }

  Future<List<StreetSuggestion>> _searchStreetsGeoapify(
    String query,
    String city,
    String countryCode,
    double cityLat,
    double cityLng,
  ) async {
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
      'text': '$query, $city',
      'type': 'street',
      'filter': 'countrycode:${countryCode.toLowerCase()}',
      'bias': 'proximity:$cityLng,$cityLat',
      'format': 'json',
      'apiKey': _geoapifyKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];

    return results
        .map((r) {
          final props = r as Map<String, dynamic>;
          return StreetSuggestion(
            name: props['street'] ?? props['name'] ?? '',
            fullAddress: props['formatted'] ?? '',
            latitude: (props['lat'] as num?)?.toDouble() ?? 0.0,
            longitude: (props['lon'] as num?)?.toDouble() ?? 0.0,
            city: props['city'] ?? city,
          );
        })
        .where((s) => s.name.isNotEmpty && s.hasValidCoordinates)
        .toList();
  }

  Future<List<StreetSuggestion>> _searchStreetsGoogle(
    String query,
    String city,
    String countryCode,
    double cityLat,
    double cityLng,
  ) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': '$query, $city',
      'types': 'route',
      'components': 'country:$countryCode',
      'location': '$cityLat,$cityLng',
      'radius': '50000', // 50km radius around city
      'key': _googlePlacesKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final predictions = (data['predictions'] as List?) ?? [];

    final results = <StreetSuggestion>[];
    for (final pred in predictions.take(5)) {
      final placeId = pred['place_id']?.toString();
      if (placeId == null) continue;

      final details = await _getGoogleStreetDetails(placeId, city);
      if (details != null) {
        results.add(details);
      }
    }

    return results;
  }

  Future<StreetSuggestion?> _getGoogleStreetDetails(
      String placeId, String city) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'geometry,formatted_address,name,address_components',
      'key': _googlePlacesKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final result = data['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    String? streetName;
    for (final comp in (result['address_components'] as List?) ?? []) {
      final types = (comp['types'] as List?)?.cast<String>() ?? [];
      if (types.contains('route')) {
        streetName = comp['long_name'];
        break;
      }
    }

    return StreetSuggestion(
      name: streetName ?? result['name']?.toString() ?? '',
      fullAddress: result['formatted_address']?.toString() ?? '',
      latitude: (location?['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location?['lng'] as num?)?.toDouble() ?? 0.0,
      city: city,
    );
  }

  /// Validate a street name and get coordinates
  Future<StreetValidationResult> validateStreet(
    String streetName, {
    required String city,
    required String countryCode,
    required double cityLat,
    required double cityLng,
  }) async {
    if (streetName.trim().isEmpty) {
      return StreetValidationResult.invalid('Street name is required');
    }

    try {
      final results = await searchStreets(
        streetName,
        city: city,
        countryCode: countryCode,
        cityLat: cityLat,
        cityLng: cityLng,
      );

      if (results.isEmpty) {
        // Try direct geocoding as fallback
        return await _directGeocode(streetName, city, countryCode);
      }

      // Find closest match
      final match = results.first;

      return StreetValidationResult.valid(
        streetName: match.name,
        latitude: match.latitude,
        longitude: match.longitude,
        formattedAddress: match.fullAddress,
      );
    } catch (e) {
      return StreetValidationResult.invalid('Error validating street: $e');
    }
  }

  /// Direct geocode attempt for manual street entry
  Future<StreetValidationResult> _directGeocode(
    String streetName,
    String city,
    String countryCode,
  ) async {
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': '$streetName, $city',
      'filter': 'countrycode:${countryCode.toLowerCase()}',
      'format': 'json',
      'apiKey': _geoapifyKey,
    });

    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      return StreetValidationResult.invalid('Could not validate street');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];

    if (results.isEmpty) {
      return StreetValidationResult.invalid(
        'Could not find "$streetName" in $city. Please check the spelling.',
      );
    }

    final first = results.first as Map<String, dynamic>;
    final lat = (first['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (first['lon'] as num?)?.toDouble() ?? 0.0;

    if (lat == 0.0 && lng == 0.0) {
      return StreetValidationResult.invalid(
        'Could not determine coordinates for "$streetName"',
      );
    }

    return StreetValidationResult.valid(
      streetName: first['street'] ?? streetName,
      latitude: lat,
      longitude: lng,
      formattedAddress: first['formatted'] ?? '$streetName, $city',
    );
  }
}

/// City suggestion from autocomplete
class CitySuggestion {
  final String name;
  final String fullName;
  final double latitude;
  final double longitude;
  final String countryCode;

  const CitySuggestion({
    required this.name,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.countryCode,
  });

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  factory CitySuggestion.empty() => const CitySuggestion(
        name: '',
        fullName: '',
        latitude: 0.0,
        longitude: 0.0,
        countryCode: '',
      );
}

/// Street suggestion from autocomplete
class StreetSuggestion {
  final String name;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String city;

  const StreetSuggestion({
    required this.name,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.city,
  });

  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;
}
