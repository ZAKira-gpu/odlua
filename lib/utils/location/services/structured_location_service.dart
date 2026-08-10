// ─────────────────────────────────────────
// Service: StructuredLocationService
// Description: Converts raw API results into StructuredAddress models.
// Contains: parseAddress, formatDisplay
// ─────────────────────────────────────────

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/location/location_config.dart';
import 'package:odlua/utils/models/location_search_models.dart';
import 'package:odlua/utils/models/structured_address_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Service for structured step-by-step location collection
/// Provides autocomplete for cities, streets, and building validation
class StructuredLocationService {
  // Cache for city search results (reduce API calls)
  static final Map<String, List<CityResult>> _cityCache = {};
  static final Map<String, List<StreetResult>> _streetCache = {};

  static const int _cacheExpiryMinutes = 30;
  static DateTime _lastCacheClear = DateTime.now();

  /// STEP 1: Search for cities by name
  /// Returns list of matching cities with coordinates
  Future<List<CityResult>> searchCities(
    String query, {
    String? countryCode,
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    // Check cache
    final cacheKey = '${query}_${countryCode ?? 'all'}';
    if (_cityCache.containsKey(cacheKey)) {
      return _cityCache[cacheKey]!;
    }

    try {
      final apiKey = await LocationConfig.geoapifyKey();

      // Build URL - filter by cities only
      final params = {
        'text': query,
        'type': 'city',
        'limit': limit.toString(),
        'apiKey': apiKey,
      };

      if (countryCode != null && countryCode.isNotEmpty) {
        params['filter'] = 'countrycode:${countryCode.toLowerCase()}';
      }

      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/autocomplete',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        final results = features
            .map((f) => CityResult.fromGeoapify(f))
            .where((c) => c.name.isNotEmpty)
            .toList();

        // Cache results
        _cityCache[cacheKey] = results;
        _clearCacheIfNeeded();

        return results;
      } else if (response.statusCode == 429) {
        DebugHelper.log('⚠️ Geoapify rate limit reached');
        return _fallbackToGooglePlaces(query, countryCode);
      } else {
        DebugHelper.log('❌ City search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      DebugHelper.log('❌ Error searching cities: $e');
      return [];
    }
  }

  /// STEP 2: Search for streets within a city
  /// Returns list of matching streets with coordinates
  Future<List<StreetResult>> searchStreets(
    String query,
    String cityCode, {
    String? countryCode,
    int limit = 10,
  }) async {
    if (query.trim().length < 2) return [];

    // Check cache
    final cacheKey = '${query}_${cityCode}_${countryCode ?? 'all'}';
    if (_streetCache.containsKey(cacheKey)) {
      return _streetCache[cacheKey]!;
    }

    try {
      final apiKey = await LocationConfig.geoapifyKey();

      // Build URL - filter by streets in specific city
      final params = {
        'text': '$query, $cityCode',
        'type': 'street',
        'limit': limit.toString(),
        'apiKey': apiKey,
      };

      if (countryCode != null && countryCode.isNotEmpty) {
        params['filter'] = 'countrycode:${countryCode.toLowerCase()}';
      }

      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/autocomplete',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        final results = features
            .map((f) => StreetResult.fromGeoapify(f))
            .where((s) => s.name.isNotEmpty)
            .toList();

        // Cache results
        _streetCache[cacheKey] = results;
        _clearCacheIfNeeded();

        return results;
      } else if (response.statusCode == 429) {
        DebugHelper.log('⚠️ Geoapify rate limit reached');
        return [];
      } else {
        DebugHelper.log('❌ Street search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      DebugHelper.log('❌ Error searching streets: $e');
      return [];
    }
  }

  /// STEP 3: Validate building number exists on street
  /// Returns validation result with coordinates if valid
  Future<BuildingValidation> validateBuildingNumber(
    String streetName,
    String buildingNumber,
    String cityCode, {
    String? countryCode,
  }) async {
    try {
      final apiKey = await LocationConfig.geoapifyKey();

      // Build full address for validation
      final fullAddress = '$buildingNumber $streetName, $cityCode';

      final params = {
        'text': fullAddress,
        'apiKey': apiKey,
      };

      if (countryCode != null && countryCode.isNotEmpty) {
        params['filter'] = 'countrycode:${countryCode.toLowerCase()}';
      }

      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/autocomplete',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        if (features.isEmpty) {
          return BuildingValidation.invalid(
            'Could not validate this address. Please verify the building number.',
          );
        }

        final firstResult = features[0]['properties'];
        final geometry = features[0]['geometry'];
        final coords = geometry['coordinates'] as List;

        return BuildingValidation.valid(
          coordinates: GeoPoint(coords[1], coords[0]),
          formattedAddress: firstResult['formatted'] ?? fullAddress,
        );
      } else {
        return BuildingValidation.invalid(
          'Could not validate address. Please check your input.',
        );
      }
    } catch (e) {
      DebugHelper.log('❌ Error validating building: $e');
      return BuildingValidation.invalid(
        'Validation failed. Please try again.',
      );
    }
  }

  /// STEP 4: Geocode complete structured address to get precise coordinates
  /// This is called after all address details are collected
  Future<GeoPoint> geocodeAddress(StructuredAddress address) async {
    try {
      final apiKey = await LocationConfig.geoapifyKey();

      // Build full address string
      final addressParts = <String>[];
      // Only include building number if provided
      if (address.buildingNumber != null &&
          address.buildingNumber!.isNotEmpty) {
        addressParts.add('${address.buildingNumber} ${address.streetName}');
      } else {
        addressParts.add(address.streetName);
      }
      addressParts.add(address.city);
      if (address.postalCode != null) {
        addressParts.add(address.postalCode!);
      }
      addressParts.add(address.country);

      final fullAddress = addressParts.join(', ');

      final params = {
        'text': fullAddress,
        'apiKey': apiKey,
      };

      if (address.countryCode != null) {
        params['filter'] = 'countrycode:${address.countryCode!.toLowerCase()}';
      }

      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/search',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        if (features.isEmpty) {
          DebugHelper.log('⚠️ No geocoding results, using address coordinates');
          return address.coordinates;
        }

        final geometry = features[0]['geometry'];
        final coords = geometry['coordinates'] as List;

        return GeoPoint(coords[1], coords[0]);
      } else {
        DebugHelper.log('❌ Geocoding failed: ${response.statusCode}');
        return address.coordinates;
      }
    } catch (e) {
      DebugHelper.log('❌ Error geocoding address: $e');
      return address.coordinates;
    }
  }

  /// Reverse geocode coordinates to get address details
  /// Useful for GPS locations or map selections
  Future<StructuredAddress?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final apiKey = await LocationConfig.geoapifyKey();

      final params = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'apiKey': apiKey,
      };

      final uri = Uri.https(
        'api.geoapify.com',
        '/v1/geocode/reverse',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];

        if (features.isEmpty) {
          return null;
        }

        final props = features[0]['properties'];

        // Helper to normalize city code
        String normalizeCityCode(String city) {
          return city.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');
        }

        // Helper to extract street type
        String? extractStreetType(String streetName) {
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
          ];
          for (final type in types) {
            if (streetName.toLowerCase().contains(type.toLowerCase())) {
              return type;
            }
          }
          return null;
        }

        return StructuredAddress(
          city: props['city'] ?? props['municipality'] ?? props['town'] ?? '',
          cityCode: normalizeCityCode(props['city'] ?? ''),
          country: props['country'] ?? '',
          countryCode: (props['country_code'] ?? '').toUpperCase(),
          streetName: props['street'] ?? '',
          streetType: extractStreetType(props['street'] ?? ''),
          buildingNumber: props['housenumber'] ?? '',
          postalCode: props['postcode'],
          coordinates: GeoPoint(latitude, longitude),
          formattedAddress: props['formatted'] ?? '',
          createdAt: DateTime.now(),
        );
      } else {
        DebugHelper.log('❌ Reverse geocoding failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      DebugHelper.log('❌ Error reverse geocoding: $e');
      return null;
    }
  }

  /// Fallback to Google Places API if Geoapify fails
  Future<List<CityResult>> _fallbackToGooglePlaces(
    String query,
    String? countryCode,
  ) async {
    try {
      final apiKey = await LocationConfig.googlePlacesKey();

      final params = {
        'input': query,
        'types': '(cities)',
        'key': apiKey,
      };

      if (countryCode != null) {
        params['components'] = 'country:$countryCode';
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        params,
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List? ?? [];

        // Get details for each prediction to get coordinates
        final results = <CityResult>[];
        for (final prediction in predictions.take(5)) {
          final placeId = prediction['place_id'];
          final details = await _getPlaceDetails(placeId, apiKey);
          if (details != null) {
            results.add(CityResult.fromGooglePlaces(details));
          }
        }

        return results;
      } else {
        DebugHelper.log(
            '❌ Google Places fallback failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      DebugHelper.log('❌ Error with Google Places fallback: $e');
      return [];
    }
  }

  /// Get place details from Google Places API
  Future<Map<String, dynamic>?> _getPlaceDetails(
    String placeId,
    String apiKey,
  ) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'key': apiKey,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      }
      return null;
    } catch (e) {
      DebugHelper.log('❌ Error getting place details: $e');
      return null;
    }
  }

  /// Clear cache periodically to prevent memory buildup
  void _clearCacheIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastCacheClear).inMinutes > _cacheExpiryMinutes) {
      _cityCache.clear();
      _streetCache.clear();
      _lastCacheClear = now;
      DebugHelper.log('🗑️ Location cache cleared');
    }
  }

  /// Clear all caches manually
  void clearCache() {
    _cityCache.clear();
    _streetCache.clear();
    _lastCacheClear = DateTime.now();
  }
}
