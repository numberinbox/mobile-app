import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/e164.dart';

/// Mirrors the platform rule (docs/02): TH local → +66, separators stripped,
/// 8–15 digits after +.
void main() {
  test('keeps canonical +E164', () {
    expect(normalizeE164('+66812345678'), '+66812345678');
  });

  test('converts TH local mobile to +66', () {
    expect(normalizeE164('0812345678'), '+66812345678');
    expect(normalizeE164('0912345678'), '+66912345678');
  });

  test('strips separators', () {
    expect(normalizeE164('+66 812-345-678'), '+66812345678');
    expect(normalizeE164('(081) 234-5678'), '+66812345678');
  });

  test('rejects invalid numbers', () {
    for (final bad in ['', 'abc', '12345', '+6681234', 'not-a-phone']) {
      expect(() => normalizeE164(bad), throwsArgumentError, reason: bad);
    }
  });
}
