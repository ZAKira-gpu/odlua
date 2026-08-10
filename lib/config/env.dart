// ─────────────────────────────────────────
// Config: Environment Variables
// Description: Build-time environment variable access via --dart-define.
// Contains: geoapifyApiKey
// ─────────────────────────────────────────

class Env {
  static const String geoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: 'YOUR_FALLBACK_KEY',
  );
}
