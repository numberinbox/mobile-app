@TestOn('vm')

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:tmail_ui_user/features/caching/config/hive_cache_client.dart';
import 'package:tmail_ui_user/features/caching/config/hive_cache_config.dart';

const _tableName = 'EncryptedCacheClientTest';
const _plainTableName = 'PlaintextCacheClientTest';

/// Serves a key the test chooses, so the encrypted-open paths can be exercised
/// without the platform key store.
class _KeyedCacheClient extends HiveCacheClient<String> {
  _KeyedCacheClient(this.key);

  final Uint8List? key;

  @override
  String get tableName => _tableName;

  @override
  bool get encryption => true;

  @override
  Future<Uint8List?> loadEncryptionKey() async => key;
}

/// A client that never asks for a key, to prove the plaintext path is
/// untouched by the encrypted-box hardening.
class _PlainCacheClient extends HiveCacheClient<String> {
  @override
  String get tableName => _plainTableName;

  @override
  bool get encryption => false;
}

void main() {
  setUpAll(() async {
    await HiveCacheConfig.instance.setUp(
      cachePath: Directory.current.path,
      isolated: false,
    );
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(_tableName);
    await Hive.deleteBoxFromDisk(_plainTableName);
  });

  group('[encrypted box]', () {
    test('should open with a well-formed key', () async {
      final client = _KeyedCacheClient(Uint8List.fromList(Hive.generateSecureKey()));

      final box = await client.openBox();

      await box.put('key', 'value');
      expect(box.get('key'), 'value');
    });

    test('should refuse to open when the key is missing', () async {
      // Opening without a cipher would create a plaintext box under the same
      // name, so the next start reads "nothing" out of a box that looks like
      // the user's stored session.
      final client = _KeyedCacheClient(null);

      await expectLater(
        client.openBox(),
        throwsA(isA<HiveEncryptionKeyException>()),
      );
      expect(
        Hive.isBoxOpen(_tableName),
        isFalse,
        reason: 'a missing key must not leave a box open at all',
      );
      expect(
        File('$_tableName.hive').existsSync(),
        isFalse,
        reason: 'a missing key must not create an unencrypted box file',
      );
    });

    test('should refuse to open when the key is empty', () async {
      final client = _KeyedCacheClient(Uint8List(0));

      await expectLater(
        client.openBox(),
        throwsA(isA<HiveEncryptionKeyException>()),
      );
      expect(Hive.isBoxOpen(_tableName), isFalse);
    });

    test('should refuse to open when the key has the wrong length', () async {
      // A truncated or padded key decrypts to garbage rather than failing, so
      // the length is checked instead of trusted.
      final client = _KeyedCacheClient(Uint8List(16));

      await expectLater(
        client.openBox(),
        throwsA(isA<HiveEncryptionKeyException>()),
      );
      expect(Hive.isBoxOpen(_tableName), isFalse);
    });

    test('should refuse to open through an operation, not only directly',
        () async {
      final client = _KeyedCacheClient(null);

      await expectLater(
        client.getItem('key', isolated: false),
        throwsA(isA<HiveEncryptionKeyException>()),
      );
      await expectLater(
        client.insertItem('key', 'value', isolated: false),
        throwsA(isA<HiveEncryptionKeyException>()),
      );
    });

    test('the rejection says nothing about the key value', () async {
      final client = _KeyedCacheClient(null);

      Object? thrown;
      try {
        await client.openBox();
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<HiveEncryptionKeyException>());
      expect(
        thrown.toString(),
        contains(_tableName),
        reason: 'the message must name the box that failed to open',
      );
      expect(
        thrown.toString(),
        isNot(contains('key=')),
        reason: 'the message must not carry key material',
      );
    });
  });

  group('[plaintext box]', () {
    test('should still open without a key', () async {
      final client = _PlainCacheClient();

      final box = await client.openBox();

      await box.put('key', 'value');
      expect(await client.getItem('key', isolated: false), 'value');
    });
  });
}