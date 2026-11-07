import 'package:core/presentation/resources/numberinbox_palette.dart';
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
    expect(find.text('NumberInbox'), findsNothing);
    expect(find.text('Your number.\nYour inbox.'), findsOneWidget);
    for (final copy in const [
      'Your phone number is your email identity. Sign in with an SMS code, then read, write and organize your mail.',
      'Made for everyday email',
      'Messages, attachments, search and folders — in one place.',
      'Free. No ads.',
      'We don’t sell your personal data or use your mail for targeted ads.',
      'Built around your choices',
      'Choose your notifications and delete your account from Settings whenever you need to.',
      'Email that starts with you.',
    ]) {
      expect(find.text(copy), findsOneWidget);
    }
    expect(find.text('Email, reimagined with your number.'), findsNothing);
    final mark = tester.widget<Image>(find.byType(Image));
    expect(mark.image, const AssetImage('assets/images/numberinbox_mark.png'));
    expect(mark.width, 78);
    expect(mark.height, 78);
    expect(
      find.descendant(
        of: find.bySubtype<FilledButton>(),
        matching: find.text('Explore numberinbox.com'),
      ),
      findsOneWidget,
    );
    expect(find.bySubtype<FilledButton>(), findsOneWidget);
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

  testWidgets(
    'website action paints the shared gradient and white foreground',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));
      final button = find.bySubtype<FilledButton>();
      expect(button, findsOneWidget);
      final decorations = tester.widgetList<DecoratedBox>(
        find.ancestor(of: button, matching: find.byType(DecoratedBox)),
      );
      expect(
        decorations.any(
          (w) =>
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient ==
                  NumberInboxPalette.primaryActionGradient,
        ),
        isTrue,
      );
      final widget = tester.widget<FilledButton>(button);
      expect(
        widget.style!.foregroundColor!.resolve({}),
        NumberInboxPalette.primaryActionForeground,
      );
      expect(widget.style!.minimumSize!.resolve({})!.height, 54);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.open_in_new)).color,
        NumberInboxPalette.primaryActionForeground,
      );
    },
  );

  testWidgets('opens exactly the HTTPS homepage without adding user data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));
    await tester.ensureVisible(find.bySubtype<FilledButton>());
    await tester.tap(find.text('Explore numberinbox.com'));
    await tester.pump();

    expect(launchedUrls, ['https://numberinbox.com']);
  });

  for (final width in [320.0, 900.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          'scrollable About at $width width, $scale text, $direction',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 480);
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: direction,
                    child: child!,
                  ),
                ),
                home: const AboutNumberInbox(),
              ),
            );
            await tester.pumpAndSettle();
            final button = find.bySubtype<FilledButton>();
            for (final label in [
              'Made for everyday email',
              'Free. No ads.',
              'Built around your choices',
              'Explore numberinbox.com',
              'Email that starts with you.',
            ]) {
              final target = find.text(label);
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              expect(tester.getRect(target).left, greaterThanOrEqualTo(0));
              expect(tester.getRect(target).right, lessThanOrEqualTo(width));
              expect(tester.takeException(), isNull);
            }
            await tester.ensureVisible(button);
            expect(Directionality.of(tester.element(button)), direction);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(54));
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(launchedUrls, ['https://numberinbox.com']);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('keyboard activation opens website once', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));
    await tester.ensureVisible(find.bySubtype<FilledButton>());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(launchedUrls, ['https://numberinbox.com']);
  });

  testWidgets('back returns to the existing previous screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AboutNumberInbox(),
                ),
              ),
              child: const Text('Open About'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open About'));
    await tester.pumpAndSettle();
    expect(find.text('About NumberInbox'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open About'), findsOneWidget);
    expect(launchedUrls, isEmpty);
  });

  testWidgets('homepage link is accessible as a named actionable button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const MaterialApp(home: AboutNumberInbox()));

      for (final icon in [
        Icons.mail_outline,
        Icons.favorite_border,
        Icons.tune,
        Icons.open_in_new,
      ]) {
        expect(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
      }
      for (final heading in [
        'Made for everyday email',
        'Free. No ads.',
        'Built around your choices',
      ]) {
        expect(
          tester.getSemantics(find.text(heading)),
          containsSemantics(label: heading),
        );
      }
      expect(
        tester.getSemantics(find.bySubtype<FilledButton>()),
        containsSemantics(
          label: 'Explore numberinbox.com',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
}
