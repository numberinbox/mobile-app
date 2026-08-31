import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:dio/dio.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/otp_screen.dart';
import 'package:tmail_ui_user/features/numberinbox/theme/numberinbox_colors.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late NumberInboxAuthClient client;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:18080'));
    adapter = DioAdapter(dio: dio);
    client = NumberInboxAuthClient(dio);
  });

  Widget buildTestApp({required Widget child}) {
    return MaterialApp(
      theme: NumberInboxColors.theme(),
      home: child,
    );
  }

  testWidgets('OTP screen phone phase golden', (tester) async {
    await tester.pumpWidget(buildTestApp(
      child: NumberInboxOtpScreen(
        client: client,
        onSession: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byType(NumberInboxOtpScreen),
      matchesGoldenFile('golden/otp_screen_phone_phase.png'),
    );
  });

  testWidgets('OTP screen code phase golden', (tester) async {
    adapter.onPost('/v1/otp/start', (server) => server.reply(200, {'ok': true}),
        data: {'e164': '+66812345678'});

    await tester.pumpWidget(buildTestApp(
      child: NumberInboxOtpScreen(
        client: client,
        onSession: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('otp_phone_field')), '0812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();

    expect(
      find.byType(NumberInboxOtpScreen),
      matchesGoldenFile('golden/otp_screen_code_phase.png'),
    );
  });

  testWidgets('OTP screen error state golden', (tester) async {
    adapter.onPost('/v1/otp/start', (server) {
      server.reply(429, {'error': 'rate_limited'});
    }, data: {'e164': '+66812345678'});

    await tester.pumpWidget(buildTestApp(
      child: NumberInboxOtpScreen(
        client: client,
        onSession: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('otp_phone_field')), '0812345678');
    await tester.tap(find.byKey(const Key('otp_send_cta')));
    await tester.pumpAndSettle();

    expect(
      find.byType(NumberInboxOtpScreen),
      matchesGoldenFile('golden/otp_screen_error_state.png'),
    );
  });
}
