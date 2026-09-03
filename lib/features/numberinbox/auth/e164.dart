import '../phone_number_parser.dart';

/// E.164 normalization — now delegates to PhoneNumberParser (international,
/// device-locale aware). Throws on invalid.
String normalizeE164(String input) {
  final parser = PhoneNumberParser();
  final e164 = parser.parseToE164(input);
  if (e164 == null) throw ArgumentError('invalid phone number: $input');
  return e164;
}
