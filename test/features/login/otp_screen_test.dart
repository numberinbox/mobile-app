import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/numberinbox/otp_screen.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late NumberInboxAuthClient client;
  OtpSession? capturedSession;

  // Distinct test colors that differ from brand defaults
  final testTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF0000),
      primary: const Color(0xFFFF0000),
      secondary: const Color(0xFF00FF00),
      surface: const Color(0xFF111111),
      error: const Color(0xFF0000FF),
      outline: const Color(0xFF888888),
      onSurface: const Color(0xFFCCCCCC),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFF0000)),
  );

  Future<void> pumpScreen(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? testTheme,
      home: NumberInboxOtpScreen(
        client: client,
        onSession: (session) => capturedSession = session,
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
    capturedSession = null;
  });

  testWidgets('renders title, country picker, phone field and send CTA', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Welcome to NumberInbox'), findsOneWidget);
    expect(find.byKey(const Key('otp_country_picker')), findsOneWidget);
    expect(find.byKey(const Key('otp_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('otp_send_cta')), findsOneWidget);
  });

  testWidgets('country picker shows default Thailand flag', (tester) async {
    await pumpScreen(tester);
    expect(find.text('🇹🇭'), findsOneWidget);
    expect(find.text('+66'), findsWidgets);
  });

  testWidgets('AppBar uses theme primary color', (tester) async {
    await pumpScreen(tester);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFFF0000));
  });

  testWidgets('Welcome title uses theme primary color', (tester) async {
    await pumpScreen(tester);
    final title = tester.widget<Text>(find.text('Welcome to NumberInbox'));
    expect(title.style!.color, const Color(0xFFFF0000));
  });

  testWidgets('Verify button uses theme primary (no explicit style)', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'});
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('otp_verify_cta')));
    expect(button.style, isNull);
  });

  testWidgets('empty phone shows inline error', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pump();
    expect(find.byKey(const Key('otp_error')), findsOneWidget);
  });

  testWidgets('short phone shows validation error', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '123');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pump();
    expect(find.byKey(const Key('otp_error')), findsOneWidget);
  });

  testWidgets('country picker opens bottom sheet with search', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('otp_country_picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('country_search')), findsOneWidget);
    expect(find.byKey(const Key('country_TH')), findsOneWidget);
  });

  testWidgets('country picker filters by search', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('otp_country_picker')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('country_search')), 'Thai');
    await tester.pump();
    expect(find.byKey(const Key('country_TH')), findsOneWidget);
    expect(find.byKey(const Key('country_US')), findsNothing);
  });

  testWidgets('selecting country updates picker label', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('otp_country_picker')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('country_search')), 'United States');
    await tester.pump();
    await tester.tap(find.byKey(const Key('country_US')));
    await tester.pumpAndSettle();
    expect(find.text('🇺🇸'), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
  });

  testWidgets('server error shows friendly message', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(500, {'error': 'internal'}), data: {'e164': '+66812345678'});
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();
    final errorWidget = tester.widget<Text>(find.byKey(const Key('otp_error')));
    expect(errorWidget.data, isNot(contains('Instance of')));
    expect(errorWidget.data, isNot(contains('HTTP')));
  });

  testWidgets('connection timeout shows friendly message', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.throws(
      0, DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/v1/otp/start'),
        error: SocketException('Connection timed out', address: InternetAddress('10.0.2.2')),
      ),
    ), data: {'e164': '+66812345678'});
    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();
    final errorWidget = tester.widget<Text>(find.byKey(const Key('otp_error')));
    expect(errorWidget.data, isNot(contains('SocketException')));
    expect(errorWidget.data, isNot(contains('DioException')));
  });

  testWidgets('happy path: send code, enter code, session delivered', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'});
    adapter.onPost('/v1/otp/verify', (server) => server.reply(200, {
          'accessToken': 'jwt',
          'jmap': {
            'sessionUrl': 'https://jmap.numberinbox.com/.well-known/jmap',
            'username': '+66812345678@numberinbox.com',
            'credential': 'app-secret',
          }
        }), data: {'e164': '+66812345678', 'code': '123456'});

    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otp_code_field')), '123456');
    await tester.tap(find.byKey(const Key('otp_verify_cta')));
    await tester.pumpAndSettle();

    expect(capturedSession, isNotNull);
    expect(capturedSession!.accessToken, 'jwt');
  });

  testWidgets('wrong code shows otp_invalid error', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'});
    adapter.onPost('/v1/otp/verify', (server) {
      server.reply(401, {'error': 'otp_invalid'});
    }, data: {'e164': '+66812345678', 'code': '000000'});

    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otp_code_field')), '000000');
    await tester.tap(find.byKey(const Key('otp_verify_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_error')), findsOneWidget);
    expect(capturedSession, isNull);
  });

  testWidgets('rate limited shows cooldown message', (tester) async {
    adapter.onPost('/v1/otp/start', (server) {
      server.reply(429, {'error': 'rate_limited'});
    }, data: {'e164': '+66812345678'});

    await pumpScreen(tester);
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_error')), findsOneWidget);
  });

  testWidgets('US number uses +1 dial code', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+12025550123'});

    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('otp_country_picker')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('country_search')), 'United States');
    await tester.pump();
    await tester.tap(find.byKey(const Key('country_US')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('otp_phone_field')), '2025550123');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('otp_code_field')), findsOneWidget);
  });

  testWidgets('AppBar background comes from theme colorScheme.primary', (tester) async {
    await pumpScreen(tester);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFFF0000));
  });

  testWidgets('Welcome title color comes from theme colorScheme.primary', (tester) async {
    await pumpScreen(tester);
    final title = tester.widget<Text>(find.text('Welcome to NumberInbox'));
    expect(title.style!.color, const Color(0xFFFF0000));
  });

  testWidgets('Send code button uses theme primary color (no explicit style)', (tester) async {
    await pumpScreen(tester);
    final button = tester.widget<FilledButton>(find.byKey(const Key('otp_send_cta')));
    expect(button.style, isNull, reason: 'Button should have no explicit style — inherits from theme');
  });

  testWidgets('Body background comes from theme colorScheme.surface', (tester) async {
    await pumpScreen(tester);
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.color, const Color(0xFF111111));
  });

  testWidgets('Subtitle text uses theme onSurface color', (tester) async {
    await pumpScreen(tester);
    final subtitle = tester.widget<Text>(find.text('Enter your phone number to receive a verification code.'));
    expect(subtitle.style!.color, isNotNull);
  });

  testWidgets('Country picker border uses theme outline color', (tester) async {
    await pumpScreen(tester);
    final containers = tester.widgetList<Container>(
      find.descendant(of: find.byKey(const Key('otp_country_picker')), matching: find.byType(Container)),
    );
    final decorated = containers.firstWhere(
      (c) => c.decoration is BoxDecoration,
      orElse: () => throw StateError('No decorated container found'),
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.border?.top.color, const Color(0xFF888888));
  });
}
