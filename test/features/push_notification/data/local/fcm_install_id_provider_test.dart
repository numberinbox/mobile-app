import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmail_ui_user/features/push_notification/data/local/fcm_install_id_provider.dart';

void main() {
  late SharedPreferences sharedPreferences;
  late FcmInstallIdProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    provider = FcmInstallIdProvider(sharedPreferences);
  });

  group('FcmInstallIdProvider.getInstallId', () {
    test(
      'WHEN no install id is stored\n'
      'THEN returns a UUID v4 and persists it under FCM_INSTALL_ID',
      () async {
        final installId = await provider.getInstallId();

        expect(installId, isNotNull);
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(installId, matches(uuidRegex));
        expect(
          sharedPreferences.getString(FcmInstallIdProvider.installIdKey),
          equals(installId),
        );
      },
    );

    test(
      'WHEN called twice on the same installation\n'
      'THEN returns the same id so token rotation keeps its deviceClientId',
      () async {
        final first = await provider.getInstallId();
        final second = await provider.getInstallId();

        expect(second, equals(first));
      },
    );

    test(
      'WHEN a stored install id already exists\n'
      'THEN returns it and does not overwrite it',
      () async {
        const storedId = '4f8f4b2a-7f4e-4a8e-9d1e-0b6f4f2a1d3c';
        await sharedPreferences.setString(
          FcmInstallIdProvider.installIdKey,
          storedId,
        );

        final installId = await provider.getInstallId();

        expect(installId, equals(storedId));
        expect(
          sharedPreferences.getString(FcmInstallIdProvider.installIdKey),
          equals(storedId),
        );
      },
    );
  });
}
