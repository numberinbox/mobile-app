import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/utils/fcm_utils.dart';

void main() {
  group('FcmUtils::platform push state', () {
    test(
      'WHEN a platform push state is created\n'
      'THEN it is recognizable as a non-server state',
      () {
        final platformPushState = FcmUtils.createPlatformPushState();

        expect(FcmUtils.isPlatformPushState(platformPushState), isTrue);
        expect(FcmUtils.isPlatformPushState(State('2c9f1b12-b35a-43e6-9af2-0106fb53a943')), isFalse);
        expect(FcmUtils.isPlatformPushState(State('e6948d51214629057f63c03d50e19d31')), isFalse);
      },
    );

    test(
      'WHEN two platform pushes arrive\n'
      'THEN each carries a distinct state so no state comparison skips it',
      () {
        final first = FcmUtils.createPlatformPushState();
        final second = FcmUtils.createPlatformPushState();

        expect(first, isNot(equals(second)));
      },
    );
  });
}
