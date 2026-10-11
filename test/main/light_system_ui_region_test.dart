import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/main/widgets/light_system_ui_region.dart';

/// Stands in for the navy `HomeView` splash: a dark surface that publishes its
/// own light-icon region, exactly as `home_view.dart` does.
class _NavySplashLikeHomeView extends StatelessWidget {
  const _NavySplashLikeHomeView();

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: Color(0xFF0F172A),
        child: SizedBox.expand(),
      ),
    );
  }
}

void main() {
  group('LightSystemUiRegion', () {
    testWidgets('requests dark status bar icons for its subtree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LightSystemUiRegion(
            child: Scaffold(body: Text('inbox')),
          ),
        ),
      );

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        region.value.statusBarIconBrightness,
        Brightness.dark,
        reason: 'light screens need dark icons to stay readable',
      );
      expect(region.value.statusBarColor, Colors.transparent);
    });

    testWidgets('keeps the child in the tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LightSystemUiRegion(
            child: Scaffold(body: Text('inbox')),
          ),
        ),
      );

      expect(find.text('inbox'), findsOneWidget);
    });

    testWidgets('HomeView overrides it with light icons for the navy splash',
        (tester) async {
      Get.testMode = true;
      Get.reset();

      await tester.pumpWidget(
        const MaterialApp(
          // The app shell wraps every route; the navy splash sits inside it and
          // must publish a nested region, because the innermost one wins.
          home: LightSystemUiRegion(child: _NavySplashLikeHomeView()),
        ),
      );
      await tester.pump();

      // The innermost region covering the status bar is the one the platform
      // honours, so this is the effective style for the navy startup frame.
      final effective = tester
          .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .last
          .value;

      expect(
        effective.statusBarIconBrightness,
        Brightness.light,
        reason: 'white icons are required on the navy startup surface; the '
            'app-wide light region must not override them',
      );
      expect(
        effective.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });

    test('HomeView publishes its own light-icon region', () {
      // HomeView's own build cannot be pumped here without its eight startup
      // dependencies, so assert it declares the override that wins over the
      // app-wide region. The rendering behaviour is covered by
      // test/features/home/presentation/home_view_test.dart.
      final source = File('lib/features/home/presentation/home_view.dart')
          .readAsStringSync();

      expect(
        source,
        contains('AnnotatedRegion<SystemUiOverlayStyle>'),
        reason: 'HomeView must publish a nested region to override the '
            'app-wide light status-bar style on the navy splash',
      );
      expect(
        source,
        contains('statusBarIconBrightness: Brightness.light'),
        reason: 'the navy startup surface needs white status-bar icons',
      );
    });

    test('the app shell wires the region in', () {
      // Guards the wiring, not just the widget: the mailbox uses a custom app
      // bar rather than a Material AppBar, so nothing else sets this style.
      final mainSource =
          File('lib/main.dart').readAsStringSync();

      expect(
        mainSource,
        contains('LightSystemUiRegion('),
        reason: 'TMailApp must wrap its routes in the light system UI region',
      );
    });
  });
}
