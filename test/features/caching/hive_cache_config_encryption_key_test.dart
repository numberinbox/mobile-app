@TestOn('vm')

import 'dart:io';

import 'package:core/utils/logging/app_logger_registry.dart';
import 'package:core/utils/logging/log_handler.dart';
import 'package:core/utils/logging/log_level.dart';
import 'package:core/utils/logging/log_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/caching/clients/encryption_key_cache_client.dart';
import 'package:tmail_ui_user/features/caching/config/hive_cache_config.dart';
import 'package:tmail_ui_user/features/login/data/local/encryption_key_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/model/encryption_key_cache.dart';

/// Captures every dispatched [LogRecord] so tests can assert on log content.
class _CapturingLogHandler extends LogHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  String get handlerKey => 'capturing-log-handler-for-tests';

  @override
  void handle(LogRecord record) => records.add(record);

  String get everything => records.map((r) => r.rawMessage).join('\n');
}

/// The key store as a plain field. What is under test is the decision about
/// whether to generate a key, not Hive itself.
class _FakeKeyCacheManager extends EncryptionKeyCacheManager {
  _FakeKeyCacheManager() : super(EncryptionKeyCacheClient());

  EncryptionKeyCache? stored;

  @override
  Future<void> storeEncryptionKey(EncryptionKeyCache encryptionKeyCache) async {
    stored = encryptionKeyCache;
  }

  @override
  Future<EncryptionKeyCache?> getEncryptionKeyStored() async => stored;
}

/// The encryption key is the only thing that can read the encrypted boxes. If a
/// lost key is silently replaced, the boxes it protected become unreadable and
/// the session in them is gone. So a key is generated for a verified first
/// install and never for an install that already has a store.
void main() {
  late _FakeKeyCacheManager keyCacheManager;
  late _CapturingLogHandler logs;
  late Directory databaseDirectory;

  /// Puts a file where a real box would be, which is what an existing install
  /// looks like to the first-install check.
  void seedExistingBox(String name) {
    File('${databaseDirectory.path}/$name.hive').writeAsStringSync('not-a-real-box');
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Hive can only be initialised once per process, so the directory is shared
    // and cleaned between tests.
    databaseDirectory = Directory.systemTemp.createTempSync('ni_hive_key');
    await HiveCacheConfig.instance.setUp(
      cachePath: databaseDirectory.path,
      isolated: false,
    );
  });

  tearDownAll(() async {
    if (databaseDirectory.existsSync()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;

    // Start every test from an install with nothing stored.
    for (final file in databaseDirectory.listSync().whereType<File>()) {
      file.deleteSync();
    }

    keyCacheManager = _FakeKeyCacheManager();
    Get.put<EncryptionKeyCacheManager>(keyCacheManager);

    logs = _CapturingLogHandler();
    AppLoggerRegistry.instance.registerHandler(logs);
  });

  tearDown(() {
    HiveCacheConfig.isFirstInstallOverride = null;
    AppLoggerRegistry.instance.resetForTesting();
    Get.reset();
  });

  group('[first install]', () {
    test('generates a key when nothing has been stored yet', () async {
      HiveCacheConfig.isFirstInstallOverride = () async => true;

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(keyCacheManager.stored, isNotNull);
      expect(keyCacheManager.stored!.value, isNotEmpty);
      expect(
        logs.records.where((r) => r.level == Level.error),
        isEmpty,
        reason: 'a first install is the one case where a new key is correct',
      );
    });

    test('keeps an existing key untouched', () async {
      keyCacheManager.stored = EncryptionKeyCache('cHJlLWV4aXN0aW5nLWtleQ==');

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(keyCacheManager.stored?.value, 'cHJlLWV4aXN0aW5nLWtleQ==');
    });

    test('never logs the key it did generate', () async {
      HiveCacheConfig.isFirstInstallOverride = () async => true;

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(
        logs.everything,
        isNot(contains(keyCacheManager.stored!.value)),
        reason: 'the generated key is written to storage and nowhere else',
      );
    });
  });

  group('[existing install]', () {
    test('does not generate a key when an encrypted store already exists',
        () async {
      // The regression: a missing key record on an install that has boxes used
      // to be treated as a first install, so a new key was written and every
      // existing box became unreadable.
      seedExistingBox('SessionCache');

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(
        keyCacheManager.stored,
        isNull,
        reason: 'a new key would orphan every encrypted box already on disk',
      );
      expect(
        logs.everything,
        contains('existing_store_without_key'),
        reason: 'the lost key has to be visible, not silent',
      );
      expect(logs.records.where((r) => r.level == Level.error), isNotEmpty);
    });

    test('reports the failure instead of pretending to start up', () async {
      // The encrypted clients fail closed on a missing key, so the app has to
      // have said something first.
      HiveCacheConfig.isFirstInstallOverride = () async => false;

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(keyCacheManager.stored, isNull);
      expect(logs.everything, contains('encryption_key_absent=true'));
    });

    test('treats an uninspectable store as existing', () async {
      // Doubt has to resolve towards not generating: a wrong guess costs the
      // user their encrypted session, the other way round costs nothing.
      HiveCacheConfig.isFirstInstallOverride = () async => false;

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(keyCacheManager.stored, isNull);
    });
  });
}
