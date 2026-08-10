// ─────────────────────────────────────────
// Controller: LocationController
// Description: GetX controller managing location state across the app.
// Contains: currentLocation, updateLocation, watchPosition
// ─────────────────────────────────────────

import 'dart:async';
import 'package:get/get.dart';
import '../models/location_models.dart';
import '../services/location_autocomplete_service.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class LocationController extends GetxController {
  final LocationAutocompleteService service;
  final Rxn<LocationData> selected = Rxn<LocationData>();
  final RxList<LocationSuggestion> suggestions = <LocationSuggestion>[].obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  Timer? _debounce;

  LocationController({required this.service});

  void onQueryChanged(String q, {String? countryCode}) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      suggestions.clear();
      return;
    }
    DebugHelper.log('Location search query: "$q"');
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        loading.value = true;
        DebugHelper.log('Fetching suggestions for: "$q"...');
        final res = await service.suggestions(q, countryCode: countryCode);
        DebugHelper.logSuccess('Got ${res.length} suggestions');
        suggestions.assignAll(res);
        error.value = '';
      } catch (e) {
        DebugHelper.logError('Error fetching suggestions: $e');
        error.value = e.toString();
      } finally {
        loading.value = false;
      }
    });
  }

  Future<void> choose(LocationSuggestion s) async {
    try {
      loading.value = true;
      final resolved = await service.resolve(s);
      if (resolved != null) {
        selected.value = resolved;
      }
    } finally {
      loading.value = false;
    }
  }
}
