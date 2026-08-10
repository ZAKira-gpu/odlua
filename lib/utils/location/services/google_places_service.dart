// ─────────────────────────────────────────
// Service: GooglePlacesService
// Description: Google Places API integration for place search.
// Contains: searchPlaces, getPlaceDetails
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/location_models.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class GooglePlacesService {
  final String apiKey;
  final Duration timeout;
  final int maxRetries;

  GooglePlacesService({
    required this.apiKey,
    this.timeout = const Duration(seconds: 6),
    this.maxRetries = 3,
  });

  /// Executes a request with exponential backoff retry logic
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() request, {
    String operationName = 'Request',
  }) async {
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);

    while (true) {
      attempt++;
      try {
        DebugHelper.log('$operationName (attempt $attempt/$maxRetries)');
        return await request();
      } catch (e) {
        final isLastAttempt = attempt >= maxRetries;
        final isRetryableError = e is SocketException ||
            e is http.ClientException ||
            e is TimeoutException;

        if (!isRetryableError || isLastAttempt) {
          DebugHelper.logError('$operationName failed after $attempt attempts: $e');
          rethrow;
        }

        DebugHelper.log('Retrying $operationName in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  Future<List<LocationSuggestion>> autocomplete(String query,
      {String? countryCode}) async {
    if (query.trim().isEmpty) return [];

    return _retryWithBackoff(
      () async {
        final uri = Uri.https(
            'maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': query,
          if (countryCode != null) 'components': 'country:$countryCode',
          'types': '(cities)',
          'key': apiKey,
        });

        final res = await http.get(uri).timeout(timeout);

        if (res.statusCode == 401 || res.statusCode == 403) {
          throw Exception('Invalid API key for Google Places service');
        }

        if (res.statusCode == 429) {
          throw Exception('Rate limit exceeded for Google Places service');
        }

        if (res.statusCode != 200) {
          throw Exception(
              'Google Places API returned status ${res.statusCode}: ${res.body}');
        }

        final data = json.decode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String?;

        if (status == 'REQUEST_DENIED') {
          throw Exception(
              'Google Places API request denied: ${data['error_message']}');
        }

        final preds = (data['predictions'] as List?) ?? [];

        if (preds.isEmpty) {
          DebugHelper.logInfo('No results found for "$query"');
        }

        return preds.map((p) {
          final desc = p['description']?.toString() ?? '';
          final placeId = p['place_id']?.toString() ?? '';
          return LocationSuggestion(
            id: placeId,
            title: desc.split(',').first,
            subtitle: desc.split(',').skip(1).join(', ').trim(),
            latitude: 0,
            longitude: 0,
            raw: p as Map<String, dynamic>,
          );
        }).toList();
      },
      operationName: 'Google Places autocomplete for "$query"',
    );
  }

  Future<LocationData?> detailsFromPlaceId(String placeId) async {
    return _retryWithBackoff(
      () async {
        final uri =
            Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': placeId,
          'fields': 'address_components,geometry,formatted_address',
          'key': apiKey,
        });

        final res = await http.get(uri).timeout(timeout);

        if (res.statusCode == 401 || res.statusCode == 403) {
          throw Exception('Invalid API key for Google Places service');
        }

        if (res.statusCode != 200) {
          throw Exception(
              'Google Places Details API returned status ${res.statusCode}');
        }

        final data = json.decode(res.body) as Map<String, dynamic>;
        final result = data['result'] as Map<String, dynamic>?;
        if (result == null) return null;

        final geometry = result['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble() ?? 0.0;
        final lon = (location?['lng'] as num?)?.toDouble() ?? 0.0;

        String? city;
        String? postalCode;
        String? country;
        String? countryCode;
        for (final comp in (result['address_components'] as List? ?? [])) {
          final types = (comp['types'] as List?)?.cast<String>() ?? [];
          if (types.contains('locality')) city = comp['long_name'];
          if (types.contains('postal_code')) postalCode = comp['long_name'];
          if (types.contains('country')) {
            country = comp['long_name'];
            countryCode = comp['short_name'];
          }
        }

        return LocationData(
          city: city,
          postalCode: postalCode,
          country: country,
          countryCode: countryCode,
          formattedAddress: (result['formatted_address'] ?? '').toString(),
          latitude: lat,
          longitude: lon,
        );
      },
      operationName: 'Google Places details for place_id: $placeId',
    );
  }
}
