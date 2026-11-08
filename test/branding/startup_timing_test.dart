import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Startup alignment: navigation follows initialization work, never a fixed
/// two-second hold outside the integration fixture branch. Covers the native-adjacent waits in the app controller
/// and the web bootstrap.
void main() {
  group('HomeController startup', () {
    test('two-second hold is confined to the integration-testing branch', () {
      final source = File(
        'lib/features/home/presentation/home_controller.dart',
      ).readAsStringSync();
      expect(
        _integrationHold.allMatches(source),
        hasLength(1),
        reason: 'retain the inherited integration fixture hold',
      );
      expect(
        _hasProductionHold(source),
        isFalse,
        reason: 'normal startup must not wait on the integration fixture hold',
      );
    });

    test('guard check rejects ordinary, wrong-guard and else-branch delays', () {
      for (final statement in [
        'await Future.delayed(2.seconds);',
        'if (someOtherFlag) { await Future.delayed(2.seconds); }',
        'if (PlatformInfo.isIntegrationTesting) {} else { await Future.delayed(2.seconds); }',
      ]) {
        expect(_hasProductionHold(statement), isTrue);
      }
      expect(
        _hasProductionHold(
          'if (PlatformInfo.isIntegrationTesting) { await Future.delayed(2.seconds); }',
        ),
        isFalse,
      );
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
      expect(
        violations,
        isEmpty,
        reason:
            'web startup must not hold runApp on a fixed timer:\n${violations.join('\n')}',
      );
    });
  });
}

// Exempt only the exact, standalone integration fixture branch. Any delay
// outside this block (including an else branch) still fails the original check.
final _integrationHold = RegExp(
  r'if\s*\(\s*PlatformInfo\.isIntegrationTesting\s*\)\s*\{\s*await\s+Future\.delayed\(\s*2\.seconds\s*\);\s*\}',
);

bool _hasProductionHold(String source) => RegExp(
  r'Future\.delayed\(\s*(2\.seconds|const Duration\(seconds:\s*2\)|Duration\(seconds:\s*2\))',
).hasMatch(source.replaceAll(_integrationHold, ''));
