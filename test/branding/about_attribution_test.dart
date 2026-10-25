import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/about_numberinbox.dart';

void main() {
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  const sourceUrl = 'https://numberinbox.com/open-source';
  late List<String> launchedUrls;

  setUp(() {
    launchedUrls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
          if (call.method == 'launch' || call.method == 'launchUrl') {
            final arguments = call.arguments as Map<dynamic, dynamic>;
            launchedUrls.add(arguments['url'] as String);
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
  });

  testWidgets('shows Twake attribution and legal notices without a repo URL', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));

    expect(find.textContaining('Twake Mail'), findsOneWidget);
    expect(find.textContaining('licensed under GNU AGPL v3'), findsOneWidget);
    expect(
      find.textContaining('permits recipients to use, modify, and'),
      findsOneWidget,
    );
    expect(find.textContaining('provided without warranty'), findsOneWidget);
    expect(find.text('License notices and source code'), findsOneWidget);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('opens the branded source page without adding user data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));
    await tester.tap(find.text('License notices and source code'));
    await tester.pump();

    expect(launchedUrls, [sourceUrl]);
  });

  testWidgets('fits a narrow screen with large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(home: AboutNumberInbox()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('License notices and source code'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });
}
