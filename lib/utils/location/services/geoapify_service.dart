// ─────────────────────────────────────────
// Service: GeoapifyService
// Description: Geoapify Places API integration for autocomplete.
// Contains: autocomplete, reverseGeocode, getPlaceDetails
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/location_models.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class GeoapifyService {
  final String apiKey;
  final Duration timeout;
  final int maxRetries;

  GeoapifyService({
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
        final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
          'text': query,
          if (countryCode != null) 'filter': 'countrycode:$countryCode',
          'limit': '20',
          'apiKey': apiKey,
        });

        final res = await http.get(uri).timeout(timeout);

        if (res.statusCode == 401) {
          throw Exception('Invalid API key for Geoapify service');
        }

        if (res.statusCode == 429) {
          throw Exception('Rate limit exceeded for Geoapify service');
        }

        if (res.statusCode != 200) {
          throw Exception(
              'Geoapify API returned status ${res.statusCode}: ${res.body}');
        }

        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];

        if (features.isEmpty) {
          DebugHelper.logInfo('No results found for "$query"');
        }

        return features.map((f) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final lat = (props['lat'] as num?)?.toDouble() ?? 0.0;
          final lon = (props['lon'] as num?)?.toDouble() ?? 0.0;
          final title =
              props['city'] ?? props['name'] ?? props['formatted'] ?? '';
          final subtitle = [props['state'], props['country']]
              .where((e) => (e ?? '').toString().isNotEmpty)
              .join(', ');
          return LocationSuggestion(
            id: props['place_id']?.toString() ??
                '${lat}_${lon}_${props['city'] ?? ''}',
            title: title.toString(),
            subtitle: subtitle.toString(),
            latitude: lat,
            longitude: lon,
            raw: props,
          );
        }).toList();
      },
      operationName: 'Geoapify autocomplete for "$query"',
    );
  }

  Future<LocationData?> detailsFromSuggestion(LocationSuggestion s) async {
    final props = s.raw;
    return LocationData(
      city: (props['city'] ?? props['name'])?.toString(),
      postalCode: props['postcode']?.toString(),
      country: props['country']?.toString(),
      countryCode: props['country_code']?.toString(),
      formattedAddress:
          (props['formatted'] ?? '${s.title}, ${s.subtitle}').toString(),
      latitude: s.latitude,
      longitude: s.longitude,
    );
  }
}
