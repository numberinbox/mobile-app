import 'dart:convert';
import 'dart:io';

import 'package:core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:core/utils/platform_info.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v10.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v11.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v12.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v13.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v14.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v15.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v16.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v17.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v18.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v19.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v20.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v21.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v22.dart';
import 'package:tmail_ui_user/features/base/upgradeable/upgrade_hive_database_steps_v7.dart';
import 'package:tmail_ui_user/features/caching/caching_manager.dart';
import 'package:tmail_ui_user/features/caching/config/cache_version.dart';
import 'package:tmail_ui_user/features/caching/config/fcm_isolate_name_server.dart';
import 'package:tmail_ui_user/features/login/data/local/encryption_key_cache_manager.dart';
import 'package:tmail_ui_user/features/login/data/model/encryption_key_cache.dart';
import 'package:tmail_ui_user/hive_registrar.g.dart';
import 'package:tmail_ui_user/main/bindings/network/binding_tag.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class HiveCacheConfig {

  HiveCacheConfig._internal();

  static final HiveCacheConfig _instance = HiveCacheConfig._internal();

  static HiveCacheConfig get instance => _instance;

  bool _isolatedAdaptersRegistered = false;
  bool _regularAdaptersRegistered = false;

  int _closeGeneration = 0;

  /// Where the boxes live, kept so a missing encryption key can be told apart
  /// from a first install.
  String? _databasePath;

  /// Bumped by every deliberate [closeHive], so an operation that started
  /// before one can tell it happened underneath.
  int get closeGeneration => _closeGeneration;

  Future<void> setUp({String? cachePath, bool isolated = true}) async {
    await initializeDatabase(databasePath: cachePath, isolated: isolated);
    _registerAdapter(isolated: isolated);
  }

  Future<void> initializeDatabase({
    String? databasePath,
    bool isolated = true,
  }) async {
    if (databasePath == null && PlatformInfo.isMobile) {
      Directory directory = await path_provider.getApplicationDocumentsDirectory();
      databasePath = directory.path;
    }

    if (databasePath == null) return;

    _databasePath = databasePath;

    if (isolated) {
      await IsolatedHive.init(
        databasePath,
        isolateNameServer: const FcmIsolateNameServer(),
      );
    } else {
      Hive.init(databasePath);
    }
  }

  Future<void> onUpgradeDatabase(CachingManager cachingManager) async {
    final oldVersion = await cachingManager.getLatestVersion() ?? 0;
    const newVersion = CacheVersion.hiveDBVersion;
    log('HiveCacheConfig::onUpgradeDatabase():oldVersion: $oldVersion | newVersion: $newVersion');

    await UpgradeHiveDatabaseStepsV7(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV10(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV11(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV12(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV13(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV14(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV15(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV16(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV17(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV18(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV19(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV20(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV21(cachingManager).onUpgrade(oldVersion, newVersion);
    await UpgradeHiveDatabaseStepsV22(cachingManager).onUpgrade(oldVersion, newVersion);

    if (oldVersion != newVersion) {
      await cachingManager.storeCacheVersion(newVersion);
    }
  }

  Future<void> initializeEncryptionKey() async {
    final encryptionKeyCacheManager = getBinding<EncryptionKeyCacheManager>() ?? getBinding<EncryptionKeyCacheManager>(tag: BindingTag.isolateTag);
    if (encryptionKeyCacheManager == null) {
      log('HiveCacheConfig::_initializeEncryptionKey(): encryptionKeyCacheManager not found');
      return;
    }

    // The first-install probe has to run before the key cache itself is read:
    // opening an empty key-cache box creates its .hive file on disk, and the
    // probe reads any .hive file as "existing install". Reading the cache
    // first would therefore make every fresh device look like an existing
    // install without a key, the key would never be generated, and every
    // encrypted box — including the sign-in store — would fail closed.
    final firstInstall = await isFirstInstall();

    final encryptionKeyCache = await encryptionKeyCacheManager.getEncryptionKeyStored();
    if (encryptionKeyCache != null) {
      return;
    }

    // A missing key record only means "first launch" on an install that has
    // nothing stored. On an install whose boxes already exist it means the key
    // is gone, and writing a new one would orphan every box it protected — the
    // user's session would be unreadable and the boxes that could be read would
    // be the ones written in the clear from then on. So refuse, visibly, and
    // let the encrypted clients fail closed.
    if (!firstInstall) {
      logError(
        'HiveCacheConfig::initializeEncryptionKey(): '
        'encryption_key_absent=true | reason=existing_store_without_key',
        stackTrace: StackTrace.current,
      );
      return;
    }

    final secureKey = Hive.generateSecureKey();
    final secureKeyEncode = base64Encode(secureKey);
    // Never the key itself: this line runs before any box is opened, so it
    // lands in logcat/Sentry on every cold start of every install.
    log('HiveCacheConfig::_initializeEncryptionKey(): generated new encryption key');
    await encryptionKeyCacheManager.storeEncryptionKey(EncryptionKeyCache(secureKeyEncode));
  }

  /// Whether this install has never stored anything.
  ///
  /// Uses the on-disk box files where there is a database directory, and the
  /// stored cache version on web, where IndexedDB cannot be listed. Anything
  /// that cannot be inspected counts as an existing install: generating a key
  /// on a doubt is the worse failure.
  @visibleForTesting
  Future<bool> isFirstInstall() async {
    final override = isFirstInstallOverride;
    if (override != null) return override();

    final databasePath = _databasePath;
    if (databasePath != null) {
      final directory = Directory(databasePath);
      if (!directory.existsSync()) return true;
      // The key cache's own artifacts are excluded on purpose: reading the
      // empty key cache opens its box, which writes these files before any
      // box holds a record. Counting them as a store would make every fresh
      // device look like an existing install without a key and fail closed.
      return !directory.listSync().whereType<File>().any(
            (file) =>
                !_isKeyCacheArtifact(file) &&
                (file.path.endsWith('.hive') || file.path.endsWith('.lock')),
          );
    }

    try {
      final cachingManager = getBinding<CachingManager>();
      final version = await cachingManager?.getLatestVersion();
      return version == null;
    } catch (e) {
      logWarning(
        'HiveCacheConfig::isFirstInstall: cannot inspect the store, '
        'treating it as existing (category=${e.runtimeType})',
      );
      return false;
    }
  }

  /// Test seam for [isFirstInstall].
  @visibleForTesting
  static Future<bool> Function()? isFirstInstallOverride;

  /// Files the key cache itself creates when it is merely opened.
  ///
  /// Hive writes a zero-length `<table>.hive` (plus `.lock`) for an empty box,
  /// so these artifacts exist on every fresh install after the key cache has
  /// been probed, and cannot say anything about prior stored state. Case
  /// folded: Hive lowercases box file names on some platforms.
  static bool _isKeyCacheArtifact(File file) {
    final name = file.path.split('/').last.toLowerCase();
    return name == 'encryptionkeycache.hive' ||
        name == 'encryptionkeycache.lock';
  }

  Future<Uint8List?> getEncryptionKey() async {
    final encryptionKeyCacheManager = getBinding<EncryptionKeyCacheManager>() ?? getBinding<EncryptionKeyCacheManager>(tag: BindingTag.isolateTag);
    if (encryptionKeyCacheManager == null) {
      // No key → an encrypted box (incl. the OIDC token box) opens without a
      // cipher and cannot be decrypted, surfacing later as a "no token" startup
      // logout. Emit remotely so this silent root cause is observable.
      logError(
        'HiveCacheConfig::getEncryptionKey(): '
        'encryption_key_unavailable=true | reason=cache_manager_binding_missing',
        stackTrace: StackTrace.current,
      );
      return null;
    }
    var encryptionKeyCache = await encryptionKeyCacheManager.getEncryptionKeyStored();

    if (encryptionKeyCache != null) {
      log('HiveCacheConfig::getEncryptionKey(): encryption key resolved');
      final encryptionKeyDecode = base64Decode(encryptionKeyCache.value);
      return encryptionKeyDecode;
    } else {
      logError(
        'HiveCacheConfig::getEncryptionKey(): '
        'encryption_key_unavailable=true | reason=key_cache_empty',
        stackTrace: StackTrace.current,
      );
      return null;
    }
  }

  void _registerAdapter({bool isolated = true}) {
    if (isolated) {
      if (_isolatedAdaptersRegistered) return;
      _isolatedAdaptersRegistered = true;
      IsolatedHive.registerAdapters();
    } else {
      if (_regularAdaptersRegistered) return;
      _regularAdaptersRegistered = true;
      Hive.registerAdapters();
    }
  }

  Future<void> closeHive({bool isolated = true}) async {
    // Bumped before the close, so an operation this very close aborts still
    // observes it.
    _closeGeneration++;
    if (isolated) {
      await IsolatedHive.close();
    } else {
      await Hive.close();
    }
  }
}