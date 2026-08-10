// ─────────────────────────────────────────
// Config: LocationConfig
// Description: Initialises location API keys from Firebase Remote Config.
// Contains: initialize, getGeoapifyKey, getGoogleMapsKey
// ─────────────────────────────────────────

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class LocationConfig {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _initialized = false;

  // Hardcoded fallback keys for development
  static const String _fallbackGeoapifyKey = '5518b2bedddd4602abb5e88c46cfda15';
  static const String _fallbackGooglePlacesKey =
      'AIzaSyDummy_GooglePlacesKey_ForFallback';

  /// Initialize Remote Config (call once at app startup)
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set default values
      await _remoteConfig!.setDefaults({
        'geoapify_api_key': _fallbackGeoapifyKey,
        'google_places_api_key': _fallbackGooglePlacesKey,
      });

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();
      _initialized = true;
    } catch (e) {
      // If Remote Config fails, we'll use fallback keys
      DebugHelper.logWarning('Remote Config initialization failed: $e');
      _initialized = false;
    }
  }

  static Future<String> geoapifyKey() async {
    // Try Remote Config first
    if (_initialized && _remoteConfig != null) {
      try {
        final value = _remoteConfig!.getString('geoapify_api_key');
        if (value.isNotEmpty) return value;
      } catch (e) {
        DebugHelper.logWarning('Error getting Geoapify key from Remote Config: $e');
      }
    }

    // Try dart-define environment variable
    const envKey = String.fromEnvironment('GEOAPIFY_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    // Return hardcoded fallback
    return _fallbackGeoapifyKey;
  }

  static Future<String> googlePlacesKey() async {
    // Try Remote Config first
    if (_initialized && _remoteConfig != null) {
      try {
        final value = _remoteConfig!.getString('google_places_api_key');
        if (value.isNotEmpty) return value;
      } catch (e) {
        DebugHelper.logWarning('Error getting Google Places key from Remote Config: $e');
      }
    }

    // Try dart-define environment variable
    const envKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    // Return hardcoded fallback
    return _fallbackGooglePlacesKey;
  }
}
