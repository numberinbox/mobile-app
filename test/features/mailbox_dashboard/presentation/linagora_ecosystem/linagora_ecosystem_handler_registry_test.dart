import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem_handler.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/linagora_ecosystem/linagora_ecosystem_handler_registry.dart';

final _refProvider = Provider<Ref>((ref) => ref);

class _RecordingHandler implements LinagoraEcosystemHandler {
  int loadedCalls = 0;
  int clearedCalls = 0;

  @override
  void onEcosystemLoaded(LinagoraEcosystem ecosystem) => loadedCalls++;

  @override
  void onEcosystemCleared() => clearedCalls++;
}

LinagoraEcosystem _ecosystem() =>
    LinagoraEcosystem.deserialize({'workplaceFqdnFallback': '{localPart}.x.tld'});

void main() {
  late ProviderContainer container;
  late LinagoraEcosystemHandlerRegistry registry;
  late _RecordingHandler handler;

  setUp(() {
    container = ProviderContainer();
    registry = LinagoraEcosystemHandlerRegistry(container.read(_refProvider));
    handler = _RecordingHandler();
    registry.register(handler);
  });

  tearDown(() => container.dispose());

  group('scheduleDispatchCleared', () {
    test('defers the clear past the current turn of the event loop',
        () async {
      registry
        ..dispatchLoaded(_ecosystem())
        ..scheduleDispatchCleared();

      expect(handler.loadedCalls, 1);
      expect(handler.clearedCalls, 0);

      await Future<void>.delayed(Duration.zero);

      expect(handler.clearedCalls, 1);
    });

    test('runs after a plain microtask flush', () async {
      registry.scheduleDispatchCleared();

      expect(handler.clearedCalls, 0);

      await Future<void>.microtask(() {});

      expect(handler.clearedCalls, 1);
    });

    test(
        'is superseded when a dispatch lands first '
        '(fresh dashboard remounted in the same frame)', () async {
      registry.scheduleDispatchCleared();
      registry.dispatchLoaded(_ecosystem());

      await Future<void>.delayed(Duration.zero);

      expect(handler.loadedCalls, 1);
      expect(handler.clearedCalls, 0);
    });

    test('collapses repeated scheduling in one turn into a single clear',
        () async {
      registry
        ..scheduleDispatchCleared()
        ..scheduleDispatchCleared();

      await Future<void>.delayed(Duration.zero);

      expect(handler.clearedCalls, 1);
    });
  });

  group('dispatchCleared', () {
    test('remains synchronous for callers outside a widget lifecycle',
        () {
      registry.dispatchCleared();

      expect(handler.clearedCalls, 1);
    });
  });
}
