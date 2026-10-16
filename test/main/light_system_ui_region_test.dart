import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/main/widgets/light_system_ui_region.dart';

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
