/// E.164 normalization — mirrors the platform rule (docs/02-product-rules.md):
/// strip separators, TH local `0XXXXXXXXX` → `+66…`, 8–15 digits after `+`.
String normalizeE164(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (cleaned.isEmpty) {
    throw ArgumentError('empty e164');
  }
  String digits;
  if (cleaned.startsWith('+')) {
    digits = cleaned.substring(1);
  } else if (cleaned.startsWith('0')) {
    digits = '66${cleaned.substring(1)}';
  } else {
    throw ArgumentError('not e164 or thai local: $input');
  }
  if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) {
    throw ArgumentError('invalid e164 digit count: $input');
  }
  return '+$digits';
}
