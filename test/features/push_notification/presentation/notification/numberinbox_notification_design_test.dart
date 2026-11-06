import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/local_notification_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_mail_presentation.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_notification_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'address remains the title; expanded content is escaped once without header summary',
    () {
      final mail = NumberInboxMailPresentation(
        subject: '<subject>&',
        preview: '<script>x</script>',
        sender: EmailAddress('Trusted Support', 'outsider@example.com'),
      );
      expect(mail.title, 'outsider@example.com');
      expect(mail.subject, '<subject>&');
      expect(mail.style.summaryText, isNull);
      expect(
        mail.style.bigText,
        'Trusted Support<br>&lt;subject&gt;&amp;<br>&lt;script&gt;x&lt;/script&gt;',
      );
    },
  );
  test(
    'collapsed text falls back to the preview when the subject is empty',
    () {
      final mail = NumberInboxMailPresentation(
        subject: '  ',
        preview: 'only a preview',
        sender: EmailAddress(null, 'a@example.com'),
      );
      expect(mail.collapsedText, 'only a preview');
      expect(
        NumberInboxMailPresentation(
          subject: 'Hello',
          preview: 'preview',
          sender: EmailAddress(null, 'a@example.com'),
        ).collapsedText,
        'Hello',
      );
      expect(
        NumberInboxMailPresentation(
          subject: '',
          preview: '',
          sender: EmailAddress(null, 'a@example.com'),
        ).collapsedText,
        isEmpty,
      );
    },
  );
  group('preview spacing', () {
    for (final separator in ['\n', '\r\n', '\r', '\u2028', '\u2029']) {
      test('preserves line boundary ${separator.codeUnits}', () {
        final mail = NumberInboxMailPresentation(
          subject: 'Test',
          preview: ['Hi,', 'Tested from iPhone', 'Manish'].join(separator),
        );
        expect(
          mail.style.bigText,
          'Test<br>Hi,<br>Tested from iPhone<br>Manish',
        );
      });
    }

    test('preserves tabs as spaces and supplied blank lines', () {
      final mail = NumberInboxMailPresentation(
        subject: '',
        preview: 'Hello\tManish\n\nRegards',
      );
      expect(mail.style.bigText, 'Hello Manish<br><br>Regards');
    });

    test('collapsed fallback flattens whitespace without joining words', () {
      final mail = NumberInboxMailPresentation(
        subject: '',
        preview: '  Hi,\n\nTested\t from iPhone\r\nManish  ',
      );
      expect(mail.collapsedText, 'Hi, Tested from iPhone Manish');
      expect(
        NumberInboxMailPresentation(
          subject: 'Subject',
          preview: 'a\nb',
        ).collapsedText,
        'Subject',
      );
    });

    test('escapes each line once and removes unsafe controls', () {
      final mail = NumberInboxMailPresentation(
        subject: '',
        preview: '<br>&\n<script>x</script>\u202E\u2066\u0000',
      );
      expect(
        mail.style.bigText,
        '&lt;br&gt;&amp;<br>&lt;script&gt;x&lt;/script&gt;',
      );
    });

    test(
      'does not reconstruct flat previews and accepts absent or Unicode text',
      () {
        for (final preview in <String?>[
          null,
          '',
          'Hi,Tested from iPhoneManish',
          'สวัสดี Manish',
        ]) {
          final mail = NumberInboxMailPresentation(
            subject: '',
            preview: preview,
          );
          expect(mail.style.bigText, preview ?? '');
          expect(mail.collapsedText, preview ?? '');
        }
      },
    );
  });

  test('a closed-app start shows the list unless it opens one valid mail', () {
    final valid = const NumberInboxNotificationTarget(
      accountId: 'account',
      emailId: 'email',
    ).encode();
    expect(
      numberInboxStartNeedsListScreen(actionId: null, payload: valid),
      isFalse,
    );
    expect(
      numberInboxStartNeedsListScreen(actionId: '', payload: valid),
      isFalse,
    );
    for (final action in ['mark_read', 'archive', 'reply', 'unknown']) {
      expect(
        numberInboxStartNeedsListScreen(actionId: action, payload: valid),
        isTrue,
      );
    }
    expect(
      numberInboxStartNeedsListScreen(actionId: null, payload: null),
      isTrue,
    );
    expect(
      numberInboxStartNeedsListScreen(
        actionId: null,
        payload: '{"niVersion":1}',
      ),
      isTrue,
    );
  });
  test('empty and Unicode sender fields use safe fallbacks', () {
    expect(
      NumberInboxMailPresentation(
        subject: '',
        sender: EmailAddress('  ', ' '),
      ).title,
      'Unknown sender',
    );
    expect(
      NumberInboxMailPresentation(
        subject: '',
        sender: EmailAddress('สมลักษณ์', null),
      ).title,
      'สมลักษณ์',
    );
    expect(
      NumberInboxMailPresentation(
        subject: '',
        sender: EmailAddress('x\u202Eevil', 'a@example.com'),
      ).title,
      'a@example.com',
    );
  });
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
        '{}',
        '{"niVersion":2,"niAccountId":"a","emailId":"e"}',
        '{"niVersion":1,"niAccountId":"","emailId":"e"}',
        '{"niVersion":1,"niAccountId":"a","emailId":"e","url":"https://evil.example"}',
      ]) {
        expect(NumberInboxNotificationTarget.decode(payload), isNull);
      }
      expect(NumberInboxMailAction.fromId('delete'), isNull);
      expect(
        NumberInboxMailAction.fromId('reply'),
        NumberInboxMailAction.reply,
      );
    },
  );
  test(
    'native categories require foreground unlock and legacy icon default is preserved',
    () {
      final categories = LocalNotificationConfig
          .iosInitializationSettings
          .notificationCategories;
      final category = categories.single;
      expect(category.identifier, NumberInboxNotificationTarget.category);
      expect(category.actions.map((a) => a.identifier), [
        'mark_read',
        'archive',
        'reply',
      ]);
      for (final action in category.actions) {
        expect(
          action.options,
          containsAll([
            DarwinNotificationActionOption.foreground,
            DarwinNotificationActionOption.authenticationRequired,
          ]),
        );
      }
      expect(
        LocalNotificationConfig.instance
            .generateNotificationDetails()
            .android
            ?.largeIcon,
        isNotNull,
      );
      expect(
        LocalNotificationConfig.instance
            .generateNotificationDetails(largeIcon: null)
            .android
            ?.largeIcon,
        isNull,
      );
    },
  );
  test(
    'deadline prevents a late account lookup from starting a mutation',
    () async {
      final gate = Completer<bool>();
      var effects = 0;
      final result = await NumberInboxNotificationActions().run(
        action: NumberInboxMailAction.reply,
        target: const NumberInboxNotificationTarget(
          accountId: 'a',
          emailId: 'e',
        ),
        isActive: () => gate.future,
        perform: (_) async {
          effects++;
          return true;
        },
        dismiss: () async {},
        deadline: const Duration(milliseconds: 5),
      );
      expect(result, isFalse);
      gate.complete(true);
      await pumpEventQueue();
      expect(effects, 0);
    },
  );
  test('duplicate in-flight taps cannot open another composer', () async {
    final gate = Completer<bool>();
    final processor = NumberInboxNotificationActions();
    const target = NumberInboxNotificationTarget(accountId: 'a', emailId: 'e');
    var effects = 0;
    final first = processor.run(
      action: NumberInboxMailAction.reply,
      target: target,
      isActive: () async => true,
      perform: (_) async {
        effects++;
        return gate.future;
      },
      dismiss: () async {},
    );
    await pumpEventQueue();
    expect(processor.isProcessing(NumberInboxMailAction.reply, target), isTrue);
    expect(
      await processor.run(
        action: NumberInboxMailAction.reply,
        target: target,
        isActive: () async => true,
        perform: (_) async => fail('duplicate'),
        dismiss: () async {},
      ),
      isFalse,
    );
    gate.complete(true);
    expect(await first, isTrue);
    expect(
      processor.isProcessing(NumberInboxMailAction.reply, target),
      isFalse,
    );
    expect(effects, 1);
  });
  test(
    'actions are foreground and require explicit mutation success before dismiss',
    () async {
      final order = <String>[];
      final processor = NumberInboxNotificationActions();
      const target = NumberInboxNotificationTarget(
        accountId: 'account',
        emailId: 'email',
      );
      expect(
        await processor.run(
          action: NumberInboxMailAction.markRead,
          target: target,
          isActive: () async => true,
          perform: (_) async {
            order.add('effect');
            return true;
          },
          dismiss: () async {
            order.add('dismiss');
          },
        ),
        isTrue,
      );
      expect(order, ['effect', 'dismiss']);
      expect(
        await processor.run(
          action: NumberInboxMailAction.markRead,
          target: target,
          isActive: () async => true,
          perform: (_) async => fail('duplicate effect'),
          dismiss: () async {},
        ),
        isTrue,
      );
    },
  );
  test(
    'account loss, offline failure and deadline leave notification intact and retriable',
    () async {
      const target = NumberInboxNotificationTarget(
        accountId: 'account',
        emailId: 'email',
      );
      final processor = NumberInboxNotificationActions();
      var effects = 0;
      expect(
        await processor.run(
          action: NumberInboxMailAction.archive,
          target: target,
          isActive: () async => false,
          perform: (_) async {
            effects++;
            return true;
          },
          dismiss: () async => fail('stale account dismissal'),
        ),
        isFalse,
      );
      expect(effects, 0);
      expect(
        await processor.run(
          action: NumberInboxMailAction.archive,
          target: target,
          isActive: () async => true,
          perform: (_) async => throw PlatformException(code: 'offline'),
          dismiss: () async => fail('failed effect dismissal'),
        ),
        isFalse,
      );
      expect(
        await processor.run(
          action: NumberInboxMailAction.archive,
          target: target,
          isActive: () async => true,
          perform: (_) async => true,
          dismiss: () async {},
        ),
        isTrue,
      );
    },
  );
}
