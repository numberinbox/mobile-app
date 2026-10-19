import 'dart:async';

import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/login/data/model/authentication_info_cache.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_page.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/branded_action_button.dart';

const _key = Key('deletion_submit');

class _Credentials implements CredentialRepository {
  @override
  Future<AuthenticationInfoCache> getAuthenticationInfoStored() async =>
      AuthenticationInfoCache('+66812345678@numberinbox.test', 'secret');

  @override
  Future<Uri> getBaseUrl() async => Uri.parse('https://jmap.numberinbox.test');
  @override
  Future removeBaseUrl() async {}
  @override
  Future<void> removeAuthenticationInfo() async {}
  @override
  Future saveBaseUrl(Uri baseUrl) async {}
  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async {}
}

/// Holds the credential read open, so the page can be observed while it is
/// still restoring.
class _PendingCredentials implements CredentialRepository {
  final Completer<AuthenticationInfoCache> _gate =
      Completer<AuthenticationInfoCache>();

  void complete() => _gate.complete(
        AuthenticationInfoCache('+66812345678@numberinbox.test', 'secret'),
      );

  @override
  Future<AuthenticationInfoCache> getAuthenticationInfoStored() => _gate.future;

  @override
  Future<Uri> getBaseUrl() async => Uri.parse('https://jmap.numberinbox.test');
  @override
  Future removeBaseUrl() async {}
  @override
  Future<void> removeAuthenticationInfo() async {}
  @override
  Future saveBaseUrl(Uri baseUrl) async {}
  @override
  Future<void> storeAuthenticationInfo(AuthenticationInfoCache info) async {}
}

class _DeletionClient extends AccountDeletionClient {
  _DeletionClient() : super(Dio());
  int calls = 0;
  int statusCalls = 0;

  @override
  Future<AccountDeletionRequest> request({
    required String confirmE164,
    required String username,
    required String password,
    required String idempotencyKey,
  }) async {
    calls++;
    return const AccountDeletionRequest('request-id', 'status-token');
  }

  @override
  Future<String> status(String requestId, String statusToken) async {
    statusCalls++;
    return 'completed';
  }
}

/// Holds the deletion request open, so the button can be observed while the
/// request is in flight.
class _PendingDeletionClient extends _DeletionClient {
  final Completer<AccountDeletionRequest> gate = Completer();

  @override
  Future<AccountDeletionRequest> request({
    required String confirmE164,
    required String username,
    required String password,
    required String idempotencyKey,
  }) {
    calls++;
    return gate.future;
  }
}

/// The [BoxDecoration] the branded button paints its gradient and radius with.
BoxDecoration buttonDecoration(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(_key),
            matching: find.byType(DecoratedBox),
          )
          .first,
    )
    .decoration as BoxDecoration;

Future<void> pumpDeletionPage(
  WidgetTester tester, {
  AccountDeletionClient? client,
  Future<void> Function()? onDeleted,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeUtils.buildAppTheme(),
      home: AccountDeletionPage(
        client: client ?? _DeletionClient(),
        credentialRepository: _Credentials(),
        onDeleted: onDeleted,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('button branding', () {
    // The deletion flow is the only NumberInbox surface still on a default
    // Material button. These assertions pin it to the same brand treatment as
    // login and OTP.
    testWidgets('is the shared branded action button', (tester) async {
      await pumpDeletionPage(tester);

      expect(
        find.ancestor(
          of: find.byKey(_key),
          matching: find.byType(BrandedActionButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is labelled Continue, not Delete account', (tester) async {
      await pumpDeletionPage(tester);

      // The button only opens the confirmation; the irreversible action is
      // the dialog action. Scoped to the button, because the app bar keeps the
      // page title "Delete account".
      expect(
        find.descendant(of: find.byKey(_key), matching: find.text('Continue')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(_key), matching: find.text('Delete account')),
        findsNothing,
      );
    });

    testWidgets('keeps the deletion_submit key on the tappable button',
        (tester) async {
      await pumpDeletionPage(tester);

      expect(
        find.byType(FilledButton),
        findsOneWidget,
        reason: 'the key has to stay on the tappable button so existing '
            'finders and accessibility lookups keep working',
      );
    });

    testWidgets('matches the login button height and radius', (tester) async {
      await pumpDeletionPage(tester);

      expect(
        tester.getSize(find.byKey(_key)).height,
        BrandedActionButton.minHeight,
      );
      expect(BrandedActionButton.minHeight, 54);

      final radius =
          buttonDecoration(tester).borderRadius! as BorderRadius;
      expect(radius.topLeft.x, BrandedActionButton.radius);
      expect(BrandedActionButton.radius, 14);
    });

    testWidgets('paints the shared primary action gradient', (tester) async {
      await pumpDeletionPage(tester);

      final gradient = buttonDecoration(tester).gradient! as LinearGradient;
      expect(
        gradient,
        NumberInboxPalette.primaryActionGradient,
        reason: 'Delete account must paint the same shared palette token as '
            'Send code and Verify, not a local copy',
      );
      expect(gradient.colors, [
        NumberInboxPalette.actionGreen,
        NumberInboxPalette.actionBlue,
      ]);
    });

    testWidgets('keeps the shared gradient while the spinner runs',
        (tester) async {
      final client = _PendingDeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        buttonDecoration(tester).gradient! as LinearGradient,
        NumberInboxPalette.primaryActionGradient,
        reason: 'the loading state keeps the brand gradient so the white '
            'spinner stays legible',
      );
    });

    testWidgets('falls back to a neutral fill while disabled', (tester) async {
      final credentials = _PendingCredentials();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeUtils.buildAppTheme(),
          home: AccountDeletionPage(
            client: _DeletionClient(),
            credentialRepository: credentials,
          ),
        ),
      );
      await tester.pump();

      final gradient = buttonDecoration(tester).gradient! as LinearGradient;
      expect(
        gradient,
        isNot(NumberInboxPalette.primaryActionGradient),
        reason: 'a disabled control must not advertise the brand gradient',
      );
      expect(
        gradient.colors.toSet(),
        {const Color(0xFFE5E7EB)},
        reason: 'the disabled fill stays the neutral gray shared with the '
            'other branded buttons',
      );
    });

    testWidgets('fills the available width', (tester) async {
      await pumpDeletionPage(tester);

      final page = tester.getSize(find.byType(AccountDeletionPage));
      expect(tester.getSize(find.byKey(_key)).width, lessThan(page.width));
      expect(tester.getSize(find.byKey(_key)).width, greaterThan(page.width * 0.8));
    });
  });

  group('confirmation flow', () {
    testWidgets('an invalid number never opens the confirmation',
        (tester) async {
      final client = _DeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '0899999999');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();

      expect(find.text('Delete permanently'), findsNothing);
      expect(find.textContaining('does not match'), findsOneWidget);
      expect(client.calls, 0);
    });

    testWidgets('Continue opens the confirmation without sending a request',
        (tester) async {
      final client = _DeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();

      expect(find.text('Delete your NumberInbox account?'), findsOneWidget);
      expect(find.text('Delete permanently'), findsOneWidget);
      expect(client.calls, 0);
    });

    testWidgets('Cancel sends no request', (tester) async {
      final client = _DeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete permanently'), findsNothing);
      expect(client.calls, 0);
      expect(
        find.text('Deleting your mailbox and account data…'),
        findsNothing,
        reason: 'nothing was requested, so there is nothing in progress',
      );
    });

    testWidgets('Delete permanently is red and sends exactly one request',
        (tester) async {
      final client = _DeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();

      final confirm = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Delete permanently'));
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        ThemeUtils.buildAppTheme().colorScheme.error,
        reason: 'red is reserved for the final irreversible action',
      );

      await tester.tap(find.text('Delete permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(client.calls, 1);
      expect(client.statusCalls, 1);
    });

    testWidgets('Cancel stays neutral next to a red confirmation',
        (tester) async {
      await pumpDeletionPage(tester);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();

      final cancel = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'));
      expect(cancel.style?.foregroundColor?.resolve(<WidgetState>{}),
          isNot(ThemeUtils.buildAppTheme().colorScheme.error));
    });
  });

  group('while the request is in flight', () {
    testWidgets('shows the spinner, blocks taps, and sends nothing twice',
        (tester) async {
      final client = _PendingDeletionClient();
      await pumpDeletionPage(tester, client: client);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.descendant(
          of: find.byKey(_key),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'the white spinner belongs on the branded gradient',
      );

      final button = tester.widget<FilledButton>(find.byKey(_key));
      expect(button.onPressed, isNull, reason: 'taps must be ignored');

      await tester.tap(find.byKey(_key), warnIfMissed: false);
      await tester.pump();
      expect(
        client.calls,
        1,
        reason: 'a second tap must not start a second deletion request',
      );

      client.gate.complete(const AccountDeletionRequest('request-id', 'status-token'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(client.statusCalls, 1);
    });

    // pumpAndSettle would only ever show the finished page, so restoration is
    // held open: the state under test is the one before it completes.
    testWidgets('is disabled and spinner-free while restoration is pending',
        (tester) async {
      final credentials = _PendingCredentials();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeUtils.buildAppTheme(),
          home: AccountDeletionPage(
            client: _DeletionClient(),
            credentialRepository: credentials,
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<FilledButton>(find.byKey(_key)).onPressed,
        isNull,
        reason: 'nothing may be submittable until the page knows whose mailbox '
            'it is deleting',
      );
      expect(
        find.descendant(
          of: find.byKey(_key),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
        reason: 'restoring a pending request is page work; a spinner on the '
            'CTA would claim a deletion is being sent',
      );

      // Finishing restoration enables the button, still without a spinner.
      credentials.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_key), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(_key)).onPressed, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(_key),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text('Deleting your mailbox and account data…'), findsNothing);
    });
  });

  group('existing behaviour', () {
    testWidgets('requires the signed-in number before deletion is offered',
        (tester) async {
      final client = _DeletionClient();
      await pumpDeletionPage(tester, client: client);

      expect(find.textContaining('Delete your NumberInbox account'), findsWidgets);
      expect(find.text('Verification code'), findsNothing);

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '0899999999');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();

      expect(find.textContaining('does not match'), findsOneWidget);
      expect(client.calls, 0);
    });

    testWidgets('confirms the signed-in number and finishes without another OTP',
        (tester) async {
      final client = _DeletionClient();
      var signedOut = false;
      await pumpDeletionPage(
        tester,
        client: client,
        onDeleted: () async => signedOut = true,
      );

      await tester.enterText(find.byKey(const Key('deletion_phone_field')), '812345678');
      await tester.tap(find.byKey(_key));
      await tester.pumpAndSettle();
      expect(find.text('Delete permanently'), findsOneWidget);
      expect(client.calls, 0);

      await tester.tap(find.text('Delete permanently'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(client.calls, 1);
      expect(client.statusCalls, 1);
      expect(signedOut, isTrue);
    });
  });
}
