import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/push_notification/domain/model/numberinbox_push_message.dart';

void main() {
  // Mirrors the FCM data map built by the platform's FcmPushGateway:
  // data.put("schemaVersion", ...), data.put("eventType", "mail.delivered"),
  // data.put("deliveryId", ...), data.put("stalwartAccountId", ...),
  // data.put("emailId", ...). The visible notification text is fixed and the
  // data payload holds opaque identifiers only.
  final backendPayload = <String, dynamic>{
    'schemaVersion': '1',
    'eventType': 'mail.delivered',
    'deliveryId': 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1',
    'stalwartAccountId': '5ff82d96f268b8699111fae83a34e562921a62865ec94d8a86a19f9c6a54ec7e',
    'emailId': 'e6948d51214629057f63c03d50e19d31',
  };

  group('NumberInboxPushMessage.tryParseFromFcmData', () {
    test(
      'WHEN the backend delivers a mail.delivered push with schemaVersion 1\n'
      'THEN parses the delivery, account and email identifiers\n'
      'AND carries the advertised schema version and event type',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData(backendPayload);

        expect(pushMessage, isNotNull);
        expect(pushMessage!.schemaVersion, '1');
        expect(pushMessage.eventType, 'mail.delivered');
        expect(pushMessage.deliveryId, 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1');
        expect(
          pushMessage.stalwartAccountId,
          '5ff82d96f268b8699111fae83a34e562921a62865ec94d8a86a19f9c6a54ec7e',
        );
        expect(pushMessage.emailId, 'e6948d51214629057f63c03d50e19d31');
      },
    );

    test(
      'WHEN the event type is not mail.delivered\n'
      'THEN returns null because the app only reacts to delivered mail',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData({
          ...backendPayload,
          'eventType': 'mail.held',
        });

        expect(pushMessage, isNull);
      },
    );

    test(
      'WHEN the schema version is newer than the app understands\n'
      'THEN returns null because the app parses by schema version',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData({
          ...backendPayload,
          'schemaVersion': '2',
        });

        expect(pushMessage, isNull);
      },
    );

    test(
      'WHEN the schema version is missing\n'
      'THEN returns null',
      () {
        final payload = <String, dynamic>{...backendPayload}..remove('schemaVersion');

        expect(NumberInboxPushMessage.tryParseFromFcmData(payload), isNull);
      },
    );

    test(
      'WHEN the event type is missing\n'
      'THEN returns null',
      () {
        final payload = <String, dynamic>{...backendPayload}..remove('eventType');

        expect(NumberInboxPushMessage.tryParseFromFcmData(payload), isNull);
      },
    );

    test(
      'WHEN the deliveryId is missing\n'
      'THEN returns null',
      () {
        final payload = <String, dynamic>{...backendPayload}..remove('deliveryId');

        expect(NumberInboxPushMessage.tryParseFromFcmData(payload), isNull);
      },
    );

    test(
      'WHEN the stalwartAccountId is empty\n'
      'THEN returns null',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData({
          ...backendPayload,
          'stalwartAccountId': '',
        });

        expect(pushMessage, isNull);
      },
    );

    test(
      'WHEN the emailId is not a string\n'
      'THEN returns null',
      () {
        final pushMessage = NumberInboxPushMessage.tryParseFromFcmData({
          ...backendPayload,
          'emailId': 42,
        });

        expect(pushMessage, isNull);
      },
    );

    test(
      'WHEN the backend sends a notification-only push without identifiers\n'
      'THEN returns null',
      () {
        expect(
          NumberInboxPushMessage.tryParseFromFcmData(
            {'schemaVersion': '1', 'eventType': 'mail.delivered'},
          ),
          isNull,
        );
      },
    );

    test(
      'WHEN the data payload is empty\n'
      'THEN returns null',
      () {
        expect(
          NumberInboxPushMessage.tryParseFromFcmData(<String, dynamic>{}),
          isNull,
        );
      },
    );
  });
}
