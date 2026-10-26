@TestOn('vm')

import 'dart:io';
import 'dart:convert';
import 'package:hive_ce/hive.dart';

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

/// Match upstream missing-key initialization while never logging key material.
void main() {
  late _FakeKeyCacheManager keyCacheManager;
  late _CapturingLogHandler logs;
  late Directory databaseDirectory;

  /// Retained store artifacts must not prevent upstream key initialization.
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
    AppLoggerRegistry.instance.resetForTesting();
    Get.reset();
  });

  group('[first install]', () {
    test('generates a key when nothing has been stored yet', () async {

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

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(
        logs.everything,
        isNot(contains(keyCacheManager.stored!.value)),
        reason: 'the generated key is written to storage and nowhere else',
      );
    });
  });

  group('[first install, key-box file race]', () {
    test('generates a key when only the empty key-box file exists', () async {
      // Reading an empty key cache can create its file before initialization.
      final raceBoxFile =
          File('${databaseDirectory.path}/encryptionkeycache.hive');
      raceBoxFile.writeAsBytesSync(const <int>[]);

      await HiveCacheConfig.instance.initializeEncryptionKey();

      expect(keyCacheManager.stored, isNotNull,
          reason: 'a device with only the empty key-box file is a first install');
      expect(keyCacheManager.stored!.value, isNotEmpty);
      expect(
        logs.records.where((r) => r.level == Level.error),
        isEmpty,
      );
    });
  });

  group('[existing install]', () {
    test('retained real encrypted Hive box follows upstream replacement behavior', () async {
      await HiveCacheConfig.instance.initializeEncryptionKey();
      final oldKey = keyCacheManager.stored!.value;
      final original = await Hive.openBox<String>('retained',
          encryptionCipher: HiveAesCipher(base64Decode(oldKey)));
      await original.put('credential', 'synthetic-local-value');
      await original.close();
      keyCacheManager.stored = null;
      await HiveCacheConfig.instance.initializeEncryptionKey();
      final replacement = keyCacheManager.stored!.value;
      expect(replacement, isNot(oldKey));
      // The installed Hive version recovers this as an empty box. This is
      // upstream compatibility, not recovery of data encrypted by the lost key.
      final reopened = await Hive.openBox<String>('retained',
          encryptionCipher: HiveAesCipher(base64Decode(replacement)));
      expect(reopened.get('credential'), isNull);
      await reopened.close();
      expect(logs.everything, isNot(contains(replacement)));
      expect(logs.everything, isNot(contains(oldKey)));
    });

    test('generates a replacement key when the key record is absent', () async {
      seedExistingBox('SessionCache');
      await HiveCacheConfig.instance.initializeEncryptionKey();
      expect(keyCacheManager.stored, isNotNull);
      expect(logs.everything, isNot(contains(keyCacheManager.stored!.value)));
    });
  });
}
