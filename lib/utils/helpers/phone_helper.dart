// ─────────────────────────────────────────
// Helper: PhoneHelper
// Description: Phone number parsing, formatting, and country-code helpers.
// Contains: formatPhone, parseInternational, getCountryCode
// ─────────────────────────────────────────

class PhoneHelper {
  /// Formats a phone number to E.164 format.
  /// Returns null if the number cannot be formatted to a valid E.164 format.
  static String formatPhoneNumber(String phone) {
    // Remove all non-digit and non-plus characters
    String digits = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If it already starts with +, validate and return it
    if (digits.startsWith('+')) {
      // Validate E.164 format: + followed by 1-15 digits
      if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(digits)) {
        return digits;
      }
      // Still return it but let Firebase reject if invalid
      return digits;
    }

    // If it starts with 00, replace with +
    if (digits.startsWith('00')) {
      return '+${digits.substring(2)}';
    }

    // Country-specific formatting based on number patterns
    // This covers the most common cases for the app's target markets

    // Egypt: 010, 011, 012, 015 (11 digits local)
    if (digits.length == 11 &&
        (digits.startsWith('010') ||
            digits.startsWith('011') ||
            digits.startsWith('012') ||
            digits.startsWith('015'))) {
      return '+20${digits.substring(1)}'; // Remove leading 0
    }

    // Jordan: 07x (10 digits local) - mobile numbers
    if (digits.length == 10 && digits.startsWith('07')) {
      return '+962${digits.substring(1)}'; // Remove leading 0
    }

    // Jordan: 079, 078, 077 patterns (10 digits)
    if (digits.length == 10 &&
        (digits.startsWith('079') ||
            digits.startsWith('078') ||
            digits.startsWith('077'))) {
      return '+962${digits.substring(1)}';
    }

    // UAE: 05x (10 digits local)
    if (digits.length == 10 && digits.startsWith('05')) {
      return '+971${digits.substring(1)}';
    }

    // Saudi Arabia: 05x (10 digits local)
    if (digits.length == 10 &&
        (digits.startsWith('050') ||
            digits.startsWith('053') ||
            digits.startsWith('054') ||
            digits.startsWith('055') ||
            digits.startsWith('056') ||
            digits.startsWith('057') ||
            digits.startsWith('058') ||
            digits.startsWith('059'))) {
      return '+966${digits.substring(1)}';
    }

    // Lebanon: 03, 70, 71, 76, 78, 79, 81 (8 digits local)
    if (digits.length == 8 &&
        (digits.startsWith('03') ||
            digits.startsWith('70') ||
            digits.startsWith('71') ||
            digits.startsWith('76') ||
            digits.startsWith('78') ||
            digits.startsWith('79') ||
            digits.startsWith('81'))) {
      return '+961$digits';
    }

    // UK: 07 (11 digits local)
    if (digits.length == 11 && digits.startsWith('07')) {
      return '+44${digits.substring(1)}';
    }

    // Germany: 01 (11-12 digits local)
    if ((digits.length == 11 || digits.length == 12) &&
        (digits.startsWith('015') ||
            digits.startsWith('016') ||
            digits.startsWith('017'))) {
      return '+49${digits.substring(1)}';
    }

    // France: 06, 07 (10 digits local)
    if (digits.length == 10 &&
        (digits.startsWith('06') || digits.startsWith('07'))) {
      return '+33${digits.substring(1)}';
    }

    // US/Canada: 10 digits -> add +1
    if (digits.length == 10) {
      return '+1$digits';
    }

    // US/Canada: 11 digits starting with 1 -> add +
    if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits';
    }

    // If number is already in international format without +
    // (e.g., 962791234567 for Jordan)
    if (digits.length >= 10 && digits.length <= 15) {
      // Check for known country codes at the start
      if (digits.startsWith('962') || // Jordan
          digits.startsWith('971') || // UAE
          digits.startsWith('966') || // Saudi
          digits.startsWith('961') || // Lebanon
          digits.startsWith('20') || // Egypt
          digits.startsWith('44') || // UK
          digits.startsWith('49') || // Germany
          digits.startsWith('33') || // France
          digits.startsWith('1')) {
        // US/Canada
        return '+$digits';
      }
    }

    // Last resort: add + and hope for the best
    // Firebase will reject invalid formats
    return '+$digits';
  }

  /// Validates if a phone number is in valid E.164 format
  static bool isValidE164(String phone) {
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone);
  }

  /// Extracts country code from E.164 formatted number
  static String? getCountryCode(String phone) {
    if (!phone.startsWith('+')) return null;

    // Common country codes (sorted by length, longest first)
    const countryCodes = [
      '962', '971', '966', '961', // Middle East (3 digits)
      '44', '49', '33', '20', // Europe/Egypt (2 digits)
      '1', // US/Canada (1 digit)
    ];

    final digits = phone.substring(1); // Remove +
    for (final code in countryCodes) {
      if (digits.startsWith(code)) {
        return '+$code';
      }
    }
    return null;
  }
}
