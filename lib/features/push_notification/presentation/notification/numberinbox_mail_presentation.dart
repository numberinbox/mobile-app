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
       preview = (preview ?? '').sanitizedBidiForDisplay,
       address = (sender?.email ?? '').sanitizedBidiForDisplay.trim(),
       name = (sender?.name ?? '').sanitizedBidiForDisplay.trim();

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
  String get collapsedText => subject.trim().isNotEmpty ? subject : preview;

  BigTextStyleInformation get style {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    final lines = [
      if (address.isNotEmpty && name.isNotEmpty && address != name) name,
      if (subject.isNotEmpty) subject,
      if (preview.isNotEmpty) preview,
    ];
    return BigTextStyleInformation(
      lines.map(escape.convert).join('<br>'),
      htmlFormatBigText: true,
      contentTitle: escape.convert(title),
      htmlFormatContentTitle: true,
    );
  }
}
