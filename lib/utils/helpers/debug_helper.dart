// ─────────────────────────────────────────
// Helper: DebugHelper
// Description: Production-safe logging (debug-mode only, replaces print).
// Contains: logInfo, logWarning, logError, logSuccess
// ─────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Debug helper for managing print statements and logging
/// Set [isDebugMode] to false before release
class DebugHelper {
  // ⚠️ IMPORTANT: Set to false before release build
  static const bool isDebugMode = kDebugMode;

  /// Log a general message (only in debug mode)
  static void log(String message, {String? tag}) {
    if (isDebugMode) {
      debugPrint('${tag != null ? '[$tag] ' : ''}$message');
    }
  }

  /// Log an error message with optional error object and stack trace
  static void logError(String message,
      {Object? error, StackTrace? stackTrace}) {
    if (isDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) debugPrint('Error object: $error');
      if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Log a warning message
  static void logWarning(String message, {String? tag}) {
    if (isDebugMode) {
      debugPrint('⚠️ ${tag != null ? '[$tag] ' : ''}WARNING: $message');
    }
  }

  /// Log a success message
  static void logSuccess(String message, {String? tag}) {
    if (isDebugMode) {
      debugPrint('✅ ${tag != null ? '[$tag] ' : ''}$message');
    }
  }

  /// Log an info message
  static void logInfo(String message, {String? tag}) {
    if (isDebugMode) {
      debugPrint('ℹ️ ${tag != null ? '[$tag] ' : ''}$message');
    }
  }
}
