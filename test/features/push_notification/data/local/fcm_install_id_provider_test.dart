import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tmail_ui_user/features/push_notification/data/local/fcm_install_id_provider.dart';

/// Stands in for the platform-backed SharedPreferences whose `getString` reads
/// only see writes after the setter round-trip completes. Without the artificial
/// round-trip delay the in-memory mock synchronizes writes and hides the race
/// the production plugin exposes.
class FakeRoundTripSharedPreferences extends Fake implements SharedPreferences {
  FakeRoundTripSharedPreferences(this._store);

  final Map<String, String> _store;

  @override
  String? getString(String key) => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _store[key] = value;
    return true;
  }
}

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
      'WHEN concurrent registration paths ask for the install id before anything is stored\n'
      'THEN every caller receives the same UUID and that UUID is the one persisted\n'
      '(needs the platform round-trip semantics)',
      () async {
        final store = <String, String>{};
        final platformBackedProvider = FcmInstallIdProvider(
          FakeRoundTripSharedPreferences(store),
        );

        final concurrent = await Future.wait([
          platformBackedProvider.getInstallId(),
          platformBackedProvider.getInstallId(),
          platformBackedProvider.getInstallId(),
        ]);

        expect(concurrent.first, isNotNull);
        expect(
          concurrent,
          everyElement(equals(concurrent.first)),
          reason: 'two callers holding different ids would register the device '
              'under identities which are no longer recoverable',
        );
        final later = await platformBackedProvider.getInstallId();
        expect(later, equals(concurrent.first),
            reason: 'the identity returned to any caller must be the persisted one');
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
