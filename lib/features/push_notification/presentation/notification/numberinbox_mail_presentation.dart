import 'dart:convert';
import 'package:core/presentation/extensions/string_extension.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

/// NumberInbox-only mapping. Upstream InboxStyle remains the shared default.
class NumberInboxMailPresentation {
  NumberInboxMailPresentation({
    required String subject,
    String? preview,
    EmailAddress? sender,
  }) : subject = subject.sanitizedBidiForDisplay,
       preview = _normalizePreview(preview ?? ''),
       address = (sender?.email ?? '').sanitizedBidiForDisplay.trim(),
       name = (sender?.name ?? '').sanitizedBidiForDisplay.trim();

  // Preserve meaningful separators before filtering unsafe controls per line.
  static String _normalizePreview(String value) => value
      .replaceAll(RegExp(r'\r\n|[\r\u2028\u2029]'), '\n')
      .replaceAll('\t', ' ')
      .split('\n')
      .map((line) => line.sanitizedBidiForDisplay)
      .join('\n');

  final String subject;
  final String preview;
  final String address;
  final String name;

  String get title => address.isNotEmpty
      ? address
      : name.isNotEmpty
      ? name
      : AppLocalizations().notificationUnknownSender;

  /// The one line shown when collapsed: the subject, or the preview when the
  /// mail has no subject.
  String get collapsedText => subject.trim().isNotEmpty
      ? subject
      : preview.replaceAll(RegExp(r'\s+'), ' ').trim();

  BigTextStyleInformation get style {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    final lines = [
      if (address.isNotEmpty && name.isNotEmpty && address != name) name,
      if (subject.isNotEmpty) subject,
      if (preview.isNotEmpty) ...preview.split('\n'),
    ];
    return BigTextStyleInformation(
      lines.map(escape.convert).join('<br>'),
      htmlFormatBigText: true,
      contentTitle: escape.convert(title),
      htmlFormatContentTitle: true,
    );
  }
}
