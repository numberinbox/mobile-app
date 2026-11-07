import 'dart:convert';

/// Local notification data only; never an authentication source or FCM contract.
class NumberInboxNotificationTarget {
  const NumberInboxNotificationTarget({
    required this.accountId,
    required this.emailId,
  });
  final String accountId;
  final String emailId;
  String encode() => jsonEncode({
    'niVersion': 1,
    'niAccountId': accountId,
    'emailId': emailId,
  });

  static NumberInboxNotificationTarget? decode(String? payload) {
    if (payload == null || payload.length > 4096) return null;
    try {
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic> ||
          map['niVersion'] is! int ||
          map['niVersion'] != 1 ||
          map.keys.any(
            (key) => !{'niVersion', 'niAccountId', 'emailId'}.contains(key),
          )) {
        return null;
      }
      final account = map['niAccountId'];
      final email = map['emailId'];
      bool valid(dynamic value) =>
          value is String &&
          value.trim().isNotEmpty &&
          value.length <= 512 &&
          !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(value);
      if (!valid(account) || !valid(email)) return null;
      return NumberInboxNotificationTarget(
        accountId: account as String,
        emailId: email as String,
      );
    } catch (_) {
      return null;
    }
  }
}
