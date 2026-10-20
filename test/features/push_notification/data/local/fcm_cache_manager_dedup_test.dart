import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tmail_ui_user/features/caching/clients/fcm_cache_client.dart';
import 'package:tmail_ui_user/features/caching/clients/firebase_registration_cache_client.dart';
import 'package:tmail_ui_user/features/push_notification/data/local/fcm_cache_manager.dart';

import 'fcm_cache_manager_dedup_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<FcmCacheClient>(),
  MockSpec<FirebaseRegistrationCacheClient>(),
])

/// The native account id (Stalwart user id) the push belongs to.
const _stalwartAccountId = '29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6';

/// The deliveryId a NumberInbox mail.delivered push carries.
const _deliveryId = 'e7d3e016-2f4e-4f68-9aa8-f01c96995fe1';

/// A deliveryId belonging to another account: dedup keys are scoped per
/// account so a redelivery of the same mail never suppresses another
/// user's push.
const _otherDeliveryId = '5a2c8b90-1d4e-4f6a-9c8b-3e7f6a5d4c2b';

void main() {
  late MockFcmCacheClient mockFcmCacheClient;
  late MockFirebaseRegistrationCacheClient mockFirebaseRegistrationCacheClient;
  late FCMCacheManager fcmCacheManager;

  /// In-memory stand-in for the Hive box so the pruning behavior can be
  /// exercised at the manager level.
  final box = <String, String>{};

  setUp(() {
    mockFcmCacheClient = MockFcmCacheClient();
    mockFirebaseRegistrationCacheClient = MockFirebaseRegistrationCacheClient();
    fcmCacheManager = FCMCacheManager(
      mockFcmCacheClient,
      mockFirebaseRegistrationCacheClient,
    );
    box.clear();
    when(mockFcmCacheClient.getItem(any)).thenAnswer(
        (invocation) async => box[invocation.positionalArguments.single as String]);
    when(mockFcmCacheClient.insertItem(any, any)).thenAnswer((invocation) async {
      box[invocation.positionalArguments[0] as String] =
          invocation.positionalArguments[1] as String;
    });
    when(mockFcmCacheClient.getMapItems()).thenAnswer((_) async => Map<String, String>.of(box));
    when(mockFcmCacheClient.deleteItem(any)).thenAnswer((invocation) async {
      box.remove(invocation.positionalArguments.single as String);
    });
  });

  group('FCMCacheManager::hasProcessedDelivery', () {
    test(
      'WHEN no delivery marker is stored\n'
      'THEN the delivery has never been processed',
      () async {
        final processed = await fcmCacheManager.hasProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: DateTime.parse('2026-10-20T10:00:00Z'),
        );

        expect(processed, isFalse);
      },
    );

    test(
      'WHEN the delivery marker was recorded inside the freshness window\n'
      'THEN the delivery counts as already processed\n'
      'AND the lookup is scoped by native account id and delivery id',
      () async {
        final now = DateTime.parse('2026-10-20T10:00:00Z');
        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now,
        );

        final processed = await fcmCacheManager.hasProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now.add(const Duration(minutes: 1)),
        );

        expect(processed, isTrue);
        verify(mockFcmCacheClient.getItem(FCMCacheManager.processedDeliveryCacheKey(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
        ))).called(1);
      },
    );

    test(
      'WHEN the delivery marker is older than the freshness window\n'
      'THEN the delivery counts as unprocessed again (at-least-once replays after the window can retry)',
      () async {
        final now = DateTime.parse('2026-10-20T10:00:00Z');
        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now,
        );

        final processed = await fcmCacheManager.hasProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now.add(FCMCacheManager.platformPushDeliveryProcessedTtl + const Duration(minutes: 1)),
        );

        expect(processed, isFalse);
      },
    );

    test(
      'WHEN the stored marker value is corrupted\n'
      'THEN the delivery counts as unprocessed so the effects can still run',
      () async {
        box[FCMCacheManager.processedDeliveryCacheKey(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
        )] = 'not-a-timestamp';

        final processed = await fcmCacheManager.hasProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: DateTime.parse('2026-10-20T10:00:00Z'),
        );

        expect(processed, isFalse);
      },
    );
  });

  group('FCMCacheManager::recordProcessedDelivery', () {
    test(
      'WHEN a delivery is recorded as processed\n'
      'THEN the marker store holds the delivery id scoped by account with the completion timestamp',
      () async {
        final now = DateTime.parse('2026-10-20T10:00:00Z');

        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now,
        );

        expect(
          box,
          containsPair(
            FCMCacheManager.processedDeliveryCacheKey(
              stalwartAccountId: _stalwartAccountId,
              deliveryId: _deliveryId,
            ),
            '${now.millisecondsSinceEpoch}',
          ),
        );
        verify(mockFcmCacheClient.insertItem(
          FCMCacheManager.processedDeliveryCacheKey(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: _deliveryId,
          ),
          '${now.millisecondsSinceEpoch}',
        )).called(1);
      },
    );

    test(
      'WHEN recorded markers exceed the bounded limit\n'
      'THEN the oldest markers are dropped so the store stays within the limit',
      () async {
        final base = DateTime.parse('2026-10-20T10:00:00Z');
        const maxEntries = FCMCacheManager.platformPushDeliveryProcessedMaxEntries;

        for (var index = 0; index <= maxEntries; index++) {
          await fcmCacheManager.recordProcessedDelivery(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: 'delivery-$index',
            now: base.add(Duration(minutes: index)),
          );
        }

        final deliveryStores = box.keys
            .where((key) => key.startsWith(FCMCacheManager.platformPushDeliveryProcessedKeyPrefix))
            .toSet();
        expect(deliveryStores.length, maxEntries);
        expect(
          deliveryStores,
          isNot(contains(FCMCacheManager.processedDeliveryCacheKey(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: 'delivery-0',
          ))),
          reason: 'The oldest marker is dropped when the store is full.',
        );
        expect(
          deliveryStores,
          contains(FCMCacheManager.processedDeliveryCacheKey(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: 'delivery-$maxEntries',
          )),
        );
      },
    );

    test(
      'WHEN recorded markers age out beyond the freshness window\n'
      'THEN pruning removes them from the store so the entries cannot accumulate forever',
      () async {
        final base = DateTime.parse('2026-10-20T10:00:00Z');
        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: base,
        );

        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _otherDeliveryId,
          now: base.add(
            FCMCacheManager.platformPushDeliveryProcessedTtl + const Duration(minutes: 1),
          ),
        );

        final deliveryStores = box.keys
            .where((key) => key.startsWith(FCMCacheManager.platformPushDeliveryProcessedKeyPrefix))
            .toSet();
        expect(
          deliveryStores,
          isNot(contains(FCMCacheManager.processedDeliveryCacheKey(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: _deliveryId,
          ))),
          reason: 'Expired markers are pruned on the next record.',
        );
        expect(
          deliveryStores,
          contains(FCMCacheManager.processedDeliveryCacheKey(
            stalwartAccountId: _stalwartAccountId,
            deliveryId: _otherDeliveryId,
          )),
        );
      },
    );

    test(
      'WHEN a marker is recorded\n'
      'THEN each write is awaited and flushed through the cache client',
      () async {
        final now = DateTime.parse('2026-10-20T10:00:00Z');

        await fcmCacheManager.recordProcessedDelivery(
          stalwartAccountId: _stalwartAccountId,
          deliveryId: _deliveryId,
          now: now,
        );

        verify(mockFcmCacheClient.insertItem(any, any)).called(1);
      },
    );
  });
}
