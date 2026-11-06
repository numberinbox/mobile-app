import 'dart:async';
import 'dart:convert';

enum NumberInboxMailAction {
  markRead('mark_read'),
  archive('archive'),
  reply('reply');

  const NumberInboxMailAction(this.id);
  final String id;
  static NumberInboxMailAction? fromId(String? id) {
    for (final action in values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

/// Local notification data only; never an authentication source or FCM contract.
class NumberInboxNotificationTarget {
  const NumberInboxNotificationTarget({
    required this.accountId,
    required this.emailId,
  });
  static const category = 'numberinbox_mail_v1';
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

/// When the app is started by a notification there is no screen yet. Only a
/// plain tap on one valid mail opens a mail screen; a button press or anything
/// refused needs the list, or the loading screen would never go away.
bool numberInboxStartNeedsListScreen({
  required String? actionId,
  required String? payload,
}) =>
    (actionId != null && actionId.isNotEmpty) ||
    NumberInboxNotificationTarget.decode(payload) == null;

/// Foreground/unlock actions reuse the active app's services. Failed operations
/// remain retriable; no credentials, deferred jobs or mutation retries are stored.
class NumberInboxNotificationActions {
  final _pending = <String>{};
  final _completed = <String>{};

  String _key(
    NumberInboxMailAction action,
    NumberInboxNotificationTarget target,
  ) => '${target.accountId}\u0000${target.emailId}\u0000${action.id}';

  bool isProcessing(
    NumberInboxMailAction action,
    NumberInboxNotificationTarget target,
  ) => _pending.contains(_key(action, target));

  Future<bool> run({
    required NumberInboxMailAction action,
    required NumberInboxNotificationTarget target,
    required Future<bool> Function() isActive,
    required Future<bool> Function(Future<bool> Function() canContinue) perform,
    required Future<void> Function() dismiss,
    Duration deadline = const Duration(seconds: 20),
  }) async {
    final key = _key(action, target);
    if (_completed.contains(key)) return true;
    if (!_pending.add(key)) return false;
    var expired = false;
    try {
      final result =
          await (() async {
            if (!await isActive() || expired) return false;
            if (!await perform(() async {
                  if (expired) return false;
                  final active = await isActive();
                  return !expired && active;
                }) ||
                expired ||
                !await isActive()) {
              return false;
            }
            await dismiss();
            return !expired;
          })().timeout(
            deadline,
            onTimeout: () {
              expired = true;
              return false;
            },
          );
      if (result) {
        _completed.add(key);
        if (_completed.length > 64) _completed.remove(_completed.first);
      }
      return result;
    } catch (_) {
      return false;
    } finally {
      _pending.remove(key);
    }
  }
}
