import 'package:core/utils/config/env_loader.dart';
import 'package:core/utils/logging/formatters/web_console_formatter.dart';
import 'package:core/utils/sentry/sentry_manager.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tmail_ui_user/main.dart';
import 'package:tmail_ui_user/main/main_entry.dart';
import 'package:tmail_ui_user/main/runner/app_runner_base.dart';
import 'package:tmail_ui_user/main/runner/web_splash.dart';

Future<void> runAppWithMonitoring(Future<void> Function() runTmail) async {
  registerLogHandlers(formatter: const WebConsoleFormatter());

  await runAppGuarded(() async {
    await EnvLoader.loadEnvFile();

    await SentryManager.instance.initialize(
      appRunner: () async {
        await runTmailPreload();
        runApp(SentryWidget(child: const TMailApp()));
        // The splash overlay sits behind the canvas, so drop it only after
        // Flutter has actually painted; removing it earlier flashes raw markup.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => removeWebSplashAfterFirstFrame(),
        );
      },
      fallBackRunner: runTmail,
    );
  });
}
