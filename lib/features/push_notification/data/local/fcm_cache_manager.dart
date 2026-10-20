import 'package:core/utils/app_logger.dart';
import 'package:fcm/model/type_name.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/extensions/account_id_extensions.dart';
import 'package:tmail_ui_user/features/caching/clients/fcm_cache_client.dart';
import 'package:tmail_ui_user/features/caching/clients/firebase_registration_cache_client.dart';
import 'package:tmail_ui_user/features/caching/interaction/cache_manager_interaction.dart';
import 'package:tmail_ui_user/features/caching/utils/cache_utils.dart';
import 'package:tmail_ui_user/features/push_notification/data/model/firebase_registration_cache.dart';
import 'package:tmail_ui_user/features/push_notification/domain/exceptions/fcm_exception.dart';

class FCMCacheManager extends CacheManagerInteraction {
  /// Key prefix for the `(native account id, deliveryId)` dedup markers a
  /// NumberInbox platform push records once its effects completed. The
  /// markers live in the FCM cache box, existing state keys keep their own
  /// prefix space.
  static const platformPushDeliveryProcessedKeyPrefix = 'platform-delivery-processed';

  /// At-least-once FCM redeliveries are only seconds to minutes apart, and
  /// a push historically retried one day is still worth processing again:
  /// keep markers for one day.
  static const platformPushDeliveryProcessedTtl = Duration(hours: 24);

  /// The marker store is by nature unbounded (one entry per delivered
  /// mail), so cap it: pruning drops expired markers first, then the oldest
  /// ones.
  static const platformPushDeliveryProcessedMaxEntries = 256;

  static String processedDeliveryCacheKey({
    required String stalwartAccountId,
    required String deliveryId,
  }) =>
      '$platformPushDeliveryProcessedKeyPrefix/$stalwartAccountId/$deliveryId';

  final FcmCacheClient _fcmCacheClient;
  final FirebaseRegistrationCacheClient _firebaseRegistrationCacheClient;

  FCMCacheManager(this._fcmCacheClient,this._firebaseRegistrationCacheClient);

  /// Returns true when the `(native account id, deliveryId)` event was
  /// recorded as processed within the freshness window, so at-least-once
  /// FCM redeliveries do not repeat the mail fetch, display or navigation
  /// effects.
  Future<bool> hasProcessedDelivery({
    required String stalwartAccountId,
    required String deliveryId,
    DateTime? now,
    Duration ttl = platformPushDeliveryProcessedTtl,
  }) async {
    final currentTimestamp = now ?? DateTime.now();
    final storedValue = await _fcmCacheClient.getItem(
      processedDeliveryCacheKey(stalwartAccountId: stalwartAccountId, deliveryId: deliveryId),
    );
    final storedTimestamp = int.tryParse(storedValue ?? '');
    if (storedTimestamp == null) {
      return false;
    }
    final completedAt = DateTime.fromMillisecondsSinceEpoch(storedTimestamp);
    return currentTimestamp.isBefore(completedAt.add(ttl));
  }

  /// Records a `(native account id, deliveryId)` event as fully processed
  /// and keeps the marker store bounded: expired markers are dropped first,
  /// then the oldest ones.
  Future<void> recordProcessedDelivery({
    required String stalwartAccountId,
    required String deliveryId,
    DateTime? now,
    Duration ttl = platformPushDeliveryProcessedTtl,
    int maxEntries = platformPushDeliveryProcessedMaxEntries,
  }) async {
    final currentTimestamp = now ?? DateTime.now();
    await _fcmCacheClient.insertItem(
      processedDeliveryCacheKey(stalwartAccountId: stalwartAccountId, deliveryId: deliveryId),
      '${currentTimestamp.millisecondsSinceEpoch}',
    );
    await _pruneProcessedDeliveries(
      currentTimestamp: currentTimestamp,
      ttl: ttl,
      maxEntries: maxEntries,
    );
  }

  Future<void> _pruneProcessedDeliveries({
    required DateTime currentTimestamp,
    required Duration ttl,
    required int maxEntries,
  }) async {
    final allItems = await _fcmCacheClient.getMapItems();
    final deliveryMarkers = <String, int>{
      for (final entry in allItems.entries)
        if (entry.key.startsWith(platformPushDeliveryProcessedKeyPrefix))
          entry.key: int.tryParse(entry.value) ?? currentTimestamp.millisecondsSinceEpoch,
    };

    final expiredMarkerKeys = <String>[
      for (final entry in deliveryMarkers.entries)
        if (!currentTimestamp.isBefore(
            DateTime.fromMillisecondsSinceEpoch(entry.value).add(ttl)))
          entry.key,
    ];
    for (final expiredMarkerKey in expiredMarkerKeys) {
      await _fcmCacheClient.deleteItem(expiredMarkerKey);
      deliveryMarkers.remove(expiredMarkerKey);
    }

    while (deliveryMarkers.length > maxEntries) {
      final oldestMarkerKey = deliveryMarkers.entries
          .reduce((oldest, next) => next.value < oldest.value ? next : oldest)
          .key;
      await _fcmCacheClient.deleteItem(oldestMarkerKey);
      deliveryMarkers.remove(oldestMarkerKey);
    }
  }

  Future<void> storeStateToRefresh(AccountId accountId, UserName userName, TypeName typeName, jmap.State newState) {
    final stateKeyCache = TupleKey(typeName.value, accountId.asString, userName.value).encodeKey;
    return _fcmCacheClient.insertItem(stateKeyCache, newState.value);
  }

  Future<jmap.State> getStateToRefresh(AccountId accountId, UserName userName, TypeName typeName) async {
    final stateKeyCache = TupleKey(typeName.value, accountId.asString, userName.value).encodeKey;
    final stateValue = await _fcmCacheClient.getItem(stateKeyCache);
    if (stateValue != null) {
      return jmap.State(stateValue);
    } else {
      if (typeName == TypeName.emailDelivery) {
        throw const NotFoundEmailDeliveryStateException();
      } else {
        throw const NotFoundStateToRefreshException();
      }
    }
  }

  Future<void> deleteStateToRefresh(AccountId accountId, UserName userName, TypeName typeName) {
    final stateKeyCache = TupleKey(typeName.value, accountId.asString, userName.value).encodeKey;
    return _fcmCacheClient.deleteItem(stateKeyCache);
  }

  Future<void> clearAllStateToRefresh() async {
    return _fcmCacheClient.clearAllData();
  }

  Future<void> storeFirebaseRegistration(FirebaseRegistrationCache firebaseRegistrationCache) {
    return _firebaseRegistrationCacheClient.insertItem(
      FirebaseRegistrationCache.keyCacheValue,
      firebaseRegistrationCache
    );
  }
  
  Future<FirebaseRegistrationCache> getStoredFirebaseRegistration() async {
    final firebaseRegistration = await _firebaseRegistrationCacheClient.getItem(FirebaseRegistrationCache.keyCacheValue);
    if (firebaseRegistration == null) {
      throw const NotFoundFirebaseRegistrationCacheException();
    } else {
      return firebaseRegistration;
    }
  }

  Future<void> deleteFirebaseRegistration() async {
    await _firebaseRegistrationCacheClient.deleteItem(FirebaseRegistrationCache.keyCacheValue);
  }

  Future<void> clearAllEmailState(
    AccountId accountId,
    Session session,
  ) async {
    await deleteStateToRefresh(
      accountId,
      session.username,
      TypeName.emailDelivery,
    );
    await deleteStateToRefresh(
      accountId,
      session.username,
      TypeName.emailType,
    );
  }

  Future<void> clear() async {
    await Future.wait([
      _fcmCacheClient.clearAllData(),
      _firebaseRegistrationCacheClient.clearAllData(),
    ]);
  }

  @override
  Future<void> migrateHiveToIsolatedHive() async {
    await Future.wait([
      _migrateFcmCacheHiveToIsolatedHive(),
      _migrateFirebaseRegistrationHiveToIsolatedHive(),
    ]);
  }

  Future<void> _migrateFcmCacheHiveToIsolatedHive() async {
    try {
      final legacyMapItems = await _fcmCacheClient.getMapItems(
        isolated: false,
      );
      log('$runtimeType::migrateHiveToIsolatedHive(): Length of legacyMapItems: ${legacyMapItems.length}');
      await _fcmCacheClient.insertMultipleItem(legacyMapItems);
      log('$runtimeType::migrateHiveToIsolatedHive(): ✅ Migrate Hive box "${_fcmCacheClient.tableName}" → IsolatedHive DONE');
    } catch (e) {
      logWarning('$runtimeType::migrateHiveToIsolatedHive(): ❌ Migrate Hive box "${_fcmCacheClient.tableName}" → IsolatedHive FAILED, Error: $e');
    }
  }

  Future<void> _migrateFirebaseRegistrationHiveToIsolatedHive() async {
    try {
      final legacyMapItems = await _firebaseRegistrationCacheClient.getMapItems(
        isolated: false,
      );
      log('$runtimeType::migrateHiveToIsolatedHive(): Length of legacyMapItems: ${legacyMapItems.length}');
      await _firebaseRegistrationCacheClient.insertMultipleItem(legacyMapItems);
      log('$runtimeType::migrateHiveToIsolatedHive(): ✅ Migrate Hive box "${_firebaseRegistrationCacheClient.tableName}" → IsolatedHive DONE');
    } catch (e) {
      logWarning('$runtimeType::migrateHiveToIsolatedHive(): ❌ Migrate Hive box "${_firebaseRegistrationCacheClient.tableName}" → IsolatedHive FAILED, Error: $e');
    }
  }
}