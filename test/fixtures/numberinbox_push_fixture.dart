/// Mirrors the FCM data map built by the platform's FcmPushGateway:
/// data.put("schemaVersion", ...), data.put("eventType", "mail.delivered"),
/// data.put("deliveryId", ...), data.put("stalwartAccountId", ...),
/// data.put("emailId", ...). The visible notification text is fixed and the
/// data payload holds opaque identifiers only.
///
/// Neutral version-1 MailDelivered push payload: single source of truth for
/// the mobile receive-path contract tests (platform ticket P9). If the
/// platform updates the identifiers, update this fixture in lockstep on both
/// sides.

const platformMailDeliveredPushPayload = <String, String>{
  'schemaVersion': '1',
  'eventType': 'mail.delivered',
  'deliveryId': 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1',
  'stalwartAccountId': '29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6',
  'emailId': 'e6948d51214629057f63c03d50e19d31',
};
