import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Startup alignment: navigation follows initialization work, never a fixed
/// two-second hold. Covers the native-adjacent waits in the app controller
/// and the web bootstrap.
void main() {
  group('HomeController startup', () {
    test('no fixed two-second hold before navigation', () {
      final lines =
          File('lib/features/home/presentation/home_controller.dart')
              .readAsLinesSync();
      final violations = <String>[];
      final fixedTwoSecond = RegExp(
          r'Future\.delayed\(\s*(2\.seconds|const Duration\(seconds:\s*2\)|Duration\(seconds:\s*2\))');
      for (var i = 0; i < lines.length; i++) {
        if (fixedTwoSecond.hasMatch(lines[i])) {
          violations.add('home_controller.dart:${i + 1}: ${lines[i].trim()}');
        }
      }
      expect(violations, isEmpty,
          reason: 'startup navigation must not wait a fixed two seconds:\n'
              '${violations.join('\n')}');
    });
  });

  group('web bootstrap', () {
    test('no two-second runApp timers', () {
      final lines = File('web/index.html').readAsLinesSync();
      final violations = <String>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('}, 2000);')) {
          violations.add('web/index.html:${i + 1}: ${lines[i].trim()}');
        }
      }
      expect(violations, isEmpty,
          reason:
              'web startup must not hold runApp on a fixed timer:\n${violations.join('\n')}');
    });
  });
}
