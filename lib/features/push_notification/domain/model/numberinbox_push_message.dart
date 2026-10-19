import 'package:equatable/equatable.dart';

/// One versioned NumberInbox "new mail" push received over FCM.
///
/// Carries no mail content: the identifiers exist solely so the app can
/// validate the active account and fetch authoritative state over
/// authenticated JMAP afterwards.
class NumberInboxPushMessage with EquatableMixin {
  /// Bump this when the platform's `PushMessage.SCHEMA_VERSION` changes.
  static const String currentSchemaVersion = '1';
  static const String mailDeliveredEventType = 'mail.delivered';

  static const String _schemaVersionKey = 'schemaVersion';
  static const String _eventTypeKey = 'eventType';
  static const String _deliveryIdKey = 'deliveryId';
  static const String _stalwartAccountIdKey = 'stalwartAccountId';
  static const String _emailIdKey = 'emailId';

  final String schemaVersion;
  final String eventType;
  final String deliveryId;
  final String stalwartAccountId;
  final String emailId;

  const NumberInboxPushMessage({
    required this.schemaVersion,
    required this.eventType,
    required this.deliveryId,
    required this.stalwartAccountId,
    required this.emailId,
  });

  /// Parses the FCM data map the platform backend sends, or returns null when
  /// the payload is not a NumberInbox push this app version understands.
  static NumberInboxPushMessage? tryParseFromFcmData(Map<String, dynamic> fcmData) {
    final schemaVersion = _string(fcmData[_schemaVersionKey]);
    final eventType = _string(fcmData[_eventTypeKey]);
    if (schemaVersion == null
        || schemaVersion != currentSchemaVersion
        || eventType == null
        || eventType != mailDeliveredEventType) {
      return null;
    }

    final deliveryId = _string(fcmData[_deliveryIdKey]);
    final stalwartAccountId = _string(fcmData[_stalwartAccountIdKey]);
    final emailId = _string(fcmData[_emailIdKey]);
    if (deliveryId == null || stalwartAccountId == null || emailId == null) {
      return null;
    }

    return NumberInboxPushMessage(
      schemaVersion: schemaVersion,
      eventType: eventType,
      deliveryId: deliveryId,
      stalwartAccountId: stalwartAccountId,
      emailId: emailId,
    );
  }

  static String? _string(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        schemaVersion,
        eventType,
        deliveryId,
        stalwartAccountId,
        emailId,
      ];
}
