import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/phone_number_parser.dart';

void main() {
  test('parse phone numbers like user types', () {
    final parser = PhoneNumberParser();
    
    // The raw input user types
    final inputs = ['66951987335', '0951987335', '+66951987335', '+66-951987335'];
    for (final input in inputs) {
      final email = parser.toEmail(input);
      print('$input -> $email');
      expect(email, isNotNull, reason: 'toEmail should not return null for $input');
      expect(email, endsWith('@numberinbox.com'));
    }
  });
}
