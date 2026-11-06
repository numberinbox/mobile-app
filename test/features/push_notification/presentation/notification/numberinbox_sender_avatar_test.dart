import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/push_notification/presentation/notification/numberinbox_sender_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('initials preserve Unicode graphemes and bounded two-letter output', () {
    expect(NumberInboxSenderAvatar.initials('Alex Morgan'), 'AM');
    expect(NumberInboxSenderAvatar.initials('👩🏽‍💻 Designer'), '👩🏽‍💻D');
    expect(NumberInboxSenderAvatar.initials('สมลักษณ์'), 'ส');
    expect(NumberInboxSenderAvatar.initials('e\u0301mile'), 'E\u0301');
    expect(NumberInboxSenderAvatar.initials('   '), '');
  });
  test('local bitmap is bounded and empty avatars are absent', () async {
    expect(await NumberInboxSenderAvatar.render(' '), isNull);
    final bytes = await NumberInboxSenderAvatar.render('Alex Morgan');
    expect(bytes, isNotNull);
    final codec = await ui.instantiateImageCodec(bytes!);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 96);
    expect(frame.image.height, 96);
    frame.image.dispose();
    codec.dispose();
  });
}
