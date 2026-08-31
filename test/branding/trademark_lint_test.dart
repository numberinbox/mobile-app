import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// docs/16-branding.md: do not ship as Twake, Linagora, or TeamMail.
///
/// Phase 1 scope: user-visible branding surfaces + config identifiers.
/// Internal code identifiers are handled separately.
void main() {
  final forbidden = ['Twake', 'Linagora', 'linagora', 'TeamMail', 'teammail', 'TWAKE'];
  final allowed = [
    'based on Twake Mail (Linagora)', // AGPL attribution
    'com:linagora:params:jmap:',      // JMAP protocol URIs
    'linagora_design_flutter',        // external dependency
    'twake_previewer_flutter',        // external dependency
    'TwakeInter',                     // external font family name
    'font-family:',                   // CSS font declarations
    'linagoraPrivacyUrl',             // upstream API compat constant name
  ];

  bool hasViolation(String line) {
    if (allowed.any(line.contains)) return false;
    return forbidden.any(line.contains);
  }

  group('Phase 1: web assets', () {
    final webFiles = [
      'web/index.html',
      'web/manifest.json',
      'web/worker_service/worker_service.js',
      'web/worker_service/style.css',
      'web/login-callback.html',
      'web/logout-callback.html',
      'web/i18n/en.json',
      'web/i18n/fr.json',
      'web/i18n/de.json',
      'web/i18n/vi.json',
      'web/i18n/translater.js',
    ];

    test('no upstream trademarks in web assets', () {
      final violations = <String>[];
      for (final path in webFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (hasViolation(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'trademarks in web assets:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: iOS config', () {
    final iosFiles = [
      'ios/Runner/Info.plist',
      'ios/fastlane/Appfile',
      'ios/fastlane/Matchfile',
      'ios/TwakeMailNSE/Info.plist',
      'ios/TwakeMailNSE/TwakeMailNSE.entitlements',
      'ios/TeamMailShareExtension/TeamMailShareExtension.entitlements',
      'ios/Runner/Runner.entitlements',
      'ios/Runner/RunnerProfile.entitlements',
    ];

    test('no upstream trademarks in iOS config', () {
      final violations = <String>[];
      for (final path in iosFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (hasViolation(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'trademarks in iOS config:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: Android config', () {
    final androidFiles = [
      'android/app/src/main/AndroidManifest.xml',
      'android/fastlane/Appfile',
      'android/app/src/androidTest/java/com/numberinbox/app/MainActivityTest.java',
    ];

    test('no upstream trademarks in Android config', () {
      final violations = <String>[];
      for (final path in androidFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (hasViolation(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'trademarks in Android config:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: Flutter source', () {
    final flutterFiles = [
      'core/lib/utils/logging/handlers/console_log_handler.dart',
      'core/lib/utils/html/editor_script/quoted_reply_enter_handler_script.dart',
      'core/lib/presentation/utils/android_selection_handles_manager.dart',
      'lib/main/utils/app_config.dart',
      'lib/main/permissions/notification_permission_service.dart',
      'configurations/app_dashboard.json',
      'env.file',
    ];

    test('no upstream trademarks in Flutter config/source', () {
      final violations = <String>[];
      for (final path in flutterFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (hasViolation(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'trademarks in Flutter source:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: localization', () {
    test('no Team-mailboxes in arb files', () {
      final violations = <String>[];
      final arbDir = Directory('lib/l10n');
      if (arbDir.existsSync()) {
        for (final file in arbDir.listSync().whereType<File>()) {
          if (!file.path.endsWith('.arb')) continue;
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].contains('team-mailbox') ||
                lines[i].contains('Team-mailbox')) {
              violations.add('${file.path}:${i + 1}');
            }
          }
        }
      }
      expect(violations, isEmpty,
          reason: 'teamMailBoxes in arb files:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: URL scheme', () {
    test('no twakemail.mobile URL scheme', () {
      final violations = <String>[];
      final schemeFiles = [
        'ios/Runner/Info.plist',
        'android/app/src/main/AndroidManifest.xml',
        'ios/TwakeCore/Network/TokenRefreshManager.swift',
      ];
      for (final path in schemeFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final content = file.readAsStringSync();
        if (content.contains('twakemail.mobile') ||
            content.contains('teammail.mobile')) {
          violations.add(path);
        }
      }
      expect(violations, isEmpty,
          reason: 'old URL scheme in:\n${violations.join('\n')}');
    });
  });

  group('Phase 1: bundle IDs', () {
    test('no linagora bundle IDs', () {
      final violations = <String>[];
      final configFiles = [
        'ios/fastlane/Appfile',
        'ios/fastlane/Matchfile',
        'android/fastlane/Appfile',
        'integration_test/base/app_constants.dart',
        'integration_test/robots/mobile/mobile_app_grid_robot.dart',
        'core/test/presentation/utils/selection_handles_overlay_guard_test.dart',
      ];
      for (final path in configFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final content = file.readAsStringSync();
        if (content.contains('com.linagora')) {
          violations.add(path);
        }
      }
      expect(violations, isEmpty,
          reason: 'linagora bundle IDs in:\n${violations.join('\n')}');
    });
  });

  test('app_name is NumberInbox in every localization', () {
    final arbDir = Directory('lib/l10n');
    if (!arbDir.existsSync()) return;
    for (final file in arbDir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final content = file.readAsStringSync();
      final match = RegExp(r'"app_name"\s*:\s*"([^"]*)"').firstMatch(content);
      if (match == null) continue;
      expect(match.group(1), 'NumberInbox',
          reason: '${file.path} app_name');
    }
  });
}
