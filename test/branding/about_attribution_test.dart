import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/about_numberinbox.dart';

void main() {
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
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

  testWidgets('shows NumberInbox branding and one homepage link', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));

    expect(find.text('About NumberInbox'), findsOneWidget);
    expect(find.text('NumberInbox'), findsOneWidget);
    expect(find.text('Email, reimagined with your number.'), findsOneWidget);
    final mark = tester.widget<Image>(find.byType(Image));
    expect(mark.image, const AssetImage('assets/images/numberinbox_mark.png'));
    expect(mark.width, 72);
    expect(mark.height, 72);
    expect(
      find.descendant(
        of: find.bySubtype<TextButton>(),
        matching: find.text('numberinbox.com'),
      ),
      findsOneWidget,
    );
    expect(find.bySubtype<TextButton>(), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);

    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join('\n');
    expect(
      renderedText,
      isNot(
        matches(
          RegExp(
            r'Twake|LINAGORA|AGPL|open.source|warranty|github\.com|/open-source',
            caseSensitive: false,
          ),
        ),
      ),
    );
  });

  testWidgets('opens exactly the HTTPS homepage without adding user data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));
    await tester.tap(find.text('numberinbox.com'));
    await tester.pump();

    expect(launchedUrls, ['https://numberinbox.com']);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'homepage link works at 200% text on narrow $direction screen',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 480);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Directionality(textDirection: direction, child: child!),
            ),
            home: const AboutNumberInbox(),
          ),
        );
        await tester.pumpAndSettle();

        final link = find.bySubtype<TextButton>();
        expect(MediaQuery.textScalerOf(tester.element(link)).scale(16), 32);
        expect(Directionality.of(tester.element(link)), direction);
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(launchedUrls, ['https://numberinbox.com']);
      },
    );
  }

  testWidgets('homepage link is accessible as a named actionable button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));

      expect(
        tester.getSemantics(find.bySubtype<TextButton>()),
        containsSemantics(
          label: 'numberinbox.com',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
