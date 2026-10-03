import 'dart:ui' as ui;

import 'package:dlibphonenumber/dlibphonenumber.dart';

class PhoneNumberParser {
  static final PhoneNumberUtil _phoneUtil = PhoneNumberUtil.instance;

  /// Parse [raw] to E164. Returns null if not a valid phone number.
  /// [defaultRegion] is ISO 3166 code like 'TH', 'US'; if null, uses device locale.
  String? parseToE164(String raw, {String? defaultRegion}) {
    var cleaned = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('00')) cleaned = '+${cleaned.substring(2)}';

    // 1. If starts with '+', parse as international.
    if (cleaned.startsWith('+')) {
      return _tryParse(cleaned, '');
    }

    // 2. Try with default region (provided or device locale).
    final region = defaultRegion ?? _deviceRegion();
    if (region != null) {
      final parsed = _tryParse(cleaned, region);
      if (parsed != null) return parsed;
    }

    // 3. Try as international by prepending '+' (handles "66951987335" → "+66951987335"
    // and "+66-951..." already stripped to "+669...").
    final withPlus = _tryParse('+$cleaned', '');
    if (withPlus != null) return withPlus;

    // 4. Fallback for Thai locals with leading 0 when device is not TH
    // (e.g. "0812345678" should still map to +66 even on US device, as per existing tests).
    if (cleaned.startsWith('0')) {
      final thParsed = _tryParse(cleaned, 'TH');
      if (thParsed != null) return thParsed;
    }

    return null;
  }

  /// Strict recipient parse for composer/contact flows.
  ///
  /// - Explicit `+` numbers resolve internationally without any region.
  /// - Any other number requires an explicitly selected region, and the
  ///   complete input is passed to the library with that region — including
  ///   international dialing prefixes, which the library interprets against
  ///   the region's own metadata.
  /// - Never consults device locale, retries another region, or strips or
  ///   rewrites a dialing prefix by hand.
  /// - Returns null for unsupported characters, extensions, and numbers that
  ///   fail library parsing or validity. Never manufactures an address.
  String? parseRecipientToE164(String raw, {String? selectedRegion}) {
    if (!_isSupportedRecipientCharset(raw)) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s\-.()]'), '');
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('+')) {
      return _tryParse(cleaned, '');
    }

    final region = selectedRegion?.trim().toUpperCase();
    if (region == null || region.isEmpty) return null;
    return _tryParse(cleaned, region);
  }

  bool _isSupportedRecipientCharset(String raw) {
    if (raw.isEmpty) return false;
    // Digits with an optional single leading `+`, plus spaces, dashes,
    // parentheses, and dots. Anything else (letters, `;`, `#`, extra `+`,
    // extension markers) is rejected before parsing.
    return RegExp(r'^\+?[\d\s\-.()]+$').hasMatch(raw);
  }

  String? _tryParse(String input, String defaultRegion) {
    try {
      final number = _phoneUtil.parse(input, defaultRegion);
      if (_phoneUtil.isValidNumber(number)) {
        return _phoneUtil.format(number, PhoneNumberFormat.e164);
      }
    } catch (_) {}
    return null;
  }

  String? _deviceRegion() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final code = locale.countryCode;
      if (code != null && code.isNotEmpty) return code;
    } catch (_) {}
    return null;
  }

  String? toEmail(String raw, {String? defaultRegion}) {
    final e164 = parseToE164(raw, defaultRegion: defaultRegion);
    if (e164 == null) return null;
    return '$e164@numberinbox.com';
  }
}
