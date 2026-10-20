import 'package:core/utils/logging/app_logger_registry.dart';
import 'package:core/utils/logging/log_handler.dart';
import 'package:core/utils/logging/log_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/services/fcm_service.dart';

class _CapturingLogHandler extends LogHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  String get handlerKey => 'capturing-log-handler-for-fcm-service-tests';

  @override
  void handle(LogRecord record) => records.add(record);

  String get everything => records.map((record) => record.rawMessage).join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FcmService::handleToken logging contract', () {
    late _CapturingLogHandler logs;

    setUp(() {
      logs = _CapturingLogHandler();
      AppLoggerRegistry.instance.registerHandler(logs);
      FcmService.instance.initialStreamController();
    });

    tearDown(() async {
      AppLoggerRegistry.instance.resetForTesting();
      await FcmService.instance.closeStream();
    });

    test(
      'WHEN the FCM token changes\n'
      'THEN the token is forwarded to listeners but never reaches a log sink',
      () async {
        const tokenMarker = 'TOKENTOKEN-MARKER-fcm-service-token';
        final received = <String?>[];
        final subscription = FcmService.instance.fcmTokenStreamController!
            .stream
            .listen(received.add);
        addTearDown(subscription.cancel);

        FcmService.instance.handleToken(tokenMarker);
        await Future<void>.delayed(Duration.zero);

        expect(received, <String?>[tokenMarker],
            reason: 'the token must still reach the registration pipeline');
        expect(
          logs.everything,
          isNot(contains(tokenMarker)),
          reason: 'the FCM device token is a credential and must never be '
              'written to a log sink',
        );
        expect(logs.records, isNotEmpty,
            reason: 'the change must stay diagnosable without the value');
      },
    );
  });
}
