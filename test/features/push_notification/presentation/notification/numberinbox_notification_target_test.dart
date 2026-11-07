import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_target.dart';

void main() {
  test(
    'local action payload has no content or endpoints and refuses malformed inputs',
    () {
      const target = NumberInboxNotificationTarget(
        accountId: 'account',
        emailId: 'email',
      );
      expect(jsonDecode(target.encode()), {
        'niVersion': 1,
        'niAccountId': 'account',
        'emailId': 'email',
      });
      expect(
        NumberInboxNotificationTarget.decode(target.encode())?.accountId,
        'account',
      );
      for (final payload in [
        'not-json',
        'x' * 4097,
        jsonEncode({'niVersion': 1, 'niAccountId': 'x' * 513, 'emailId': 'e'}),
        jsonEncode({'niVersion': 1, 'niAccountId': 'a', 'emailId': 'e\u0000'}),
        '{}',
        '{"niVersion":2,"niAccountId":"a","emailId":"e"}',
        '{"niVersion":1,"niAccountId":"","emailId":"e"}',
        '{"niVersion":1,"niAccountId":"a","emailId":"e","url":"https://evil.example"}',
      ]) {
        expect(NumberInboxNotificationTarget.decode(payload), isNull);
      }
    },
  );
}
