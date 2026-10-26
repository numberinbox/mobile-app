import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/platform_api_options.dart';

void main() {
  test('platform API requests are bounded without implicit credentials', () {
    final options = platformApiOptions('https://example.test');
    expect(options.connectTimeout, const Duration(seconds: 10));
    expect(options.sendTimeout, const Duration(seconds: 10));
    expect(options.receiveTimeout, const Duration(seconds: 30));
    expect(
      options.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(options.baseUrl, 'https://example.test');
  });
}
