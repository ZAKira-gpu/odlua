// ─────────────────────────────────────────
// Service: LocationAutocompleteService
// Description: Abstraction over Geoapify/Google for address autocomplete.
// Contains: getSuggestions, selectSuggestion
// ─────────────────────────────────────────

import 'dart:collection';
import '../models/location_models.dart';
import 'geoapify_service.dart';
import 'google_places_service.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class LocationAutocompleteService {
  final GeoapifyService? geoapify;
  final GooglePlacesService? google;
  final Duration ttl;

  final _cache = HashMap<String, _CacheEntry<List<LocationSuggestion>>>();

  LocationAutocompleteService(
      {required this.geoapify,
      required this.google,
      this.ttl = const Duration(minutes: 30)});

  Future<List<LocationSuggestion>> suggestions(String query,
      {String? countryCode}) async {
    final key = '${countryCode ?? ''}|$query'.toLowerCase();
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      DebugHelper.log('Using cached results for "$query"');
      return cached.value;
    }

    List<LocationSuggestion> results = [];

    // Prefer Geoapify; fallback to Google
    if (geoapify != null) {
      try {
        DebugHelper.log('Trying Geoapify for "$query"...');
        results = await geoapify!.autocomplete(query, countryCode: countryCode);
        DebugHelper.logSuccess('Geoapify returned ${results.length} results');
      } catch (e) {
        DebugHelper.logError('Geoapify failed: $e');
      }
    } else {
      DebugHelper.logWarning('Geoapify service is null (no API key)');
    }

    if (results.isEmpty && google != null) {
      try {
        DebugHelper.log('Trying Google Places for "$query"...');
        results = await google!.autocomplete(query, countryCode: countryCode);
        DebugHelper.logSuccess('Google Places returned ${results.length} results');
      } catch (e) {
        DebugHelper.logError('Google Places failed: $e');
      }
    } else if (results.isEmpty && google == null) {
      DebugHelper.logWarning('Google Places service is null (no API key)');
    }

    if (results.isEmpty) {
      DebugHelper.logWarning('No results from any service for "$query"');
    }

    _cache[key] = _CacheEntry(results, DateTime.now().add(ttl));
    return results;
  }

  Future<LocationData?> resolve(LocationSuggestion s) async {
    // If Geoapify raw provided, resolve via Geoapify
    if (geoapify != null &&
        (s.raw['country'] != null || s.raw['formatted'] != null)) {
      try {
        return await geoapify!.detailsFromSuggestion(s);
      } catch (_) {}
    }

    // If Google Place, use details endpoint
    if (google != null && (s.id.isNotEmpty)) {
      try {
        final data = await google!.detailsFromPlaceId(s.id);
        if (data != null) return data;
      } catch (_) {}
    }

    // Fallback minimal mapping
    return LocationData(
      formattedAddress:
          s.subtitle.isNotEmpty ? '${s.title}, ${s.subtitle}' : s.title,
      latitude: s.latitude,
      longitude: s.longitude,
    );
  }
}
