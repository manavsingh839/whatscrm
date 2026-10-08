class PhoneUtils {
  /// Sanitize phone number for Meta WhatsApp API (digits only).
  static String sanitizePhoneForMeta(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Normalize phone number by removing all non-digit characters.
  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Compare two phone numbers accounting for trunk prefix differences.
  static bool phonesMatch(String phone1, String phone2) {
    final n1 = normalizePhone(phone1);
    final n2 = normalizePhone(phone2);
    if (n1 == n2) return true;
    if (n1.length >= 8 && n2.length >= 8) {
      return n1.substring(n1.length - 8) == n2.substring(n2.length - 8);
    }
    return false;
  }

  /// Validate E.164-like phone number (8–15 digits starting with non-zero).
  static bool isValidE164(String phone) {
    return RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(phone);
  }

  /// Format phone number with leading + if missing for international display.
  static String formatDisplay(String phone) {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('+')) return cleaned;
    return '+$cleaned';
  }
}
