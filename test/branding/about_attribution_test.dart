import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/16-branding.md — required AGPL-3.0 attribution, shipped in-app.
void main() {
  test('AGPL attribution with source URL exists in the app', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      if (content.contains('based on Twake Mail (Linagora)') &&
          content.contains('github.com/numberinbox/mobile-app')) {
        return; // found
      }
    }
    fail('no AGPL attribution found under lib/ — expected the docs/16 '
        'wording plus the source URL github.com/numberinbox/mobile-app');
  });
}
