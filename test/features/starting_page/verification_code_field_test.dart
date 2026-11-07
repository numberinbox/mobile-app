import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/verification_code_field.dart';

void main() {
  late TextEditingController controller;
  late int submissions;
  const field = Key('otp_code_field');
  Finder box(int i) => find.byKey(ValueKey('otp_digit_box_$i'));
  String digit(WidgetTester tester, int i) => tester
      .widget<Text>(find.descendant(of: box(i), matching: find.byType(Text)))
      .data!;
  BoxDecoration decoration(WidgetTester tester, int i) =>
      tester.widget<Container>(box(i)).decoration! as BoxDecoration;

  setUp(() {
    controller = TextEditingController();
    submissions = 0;
  });
  tearDown(() => controller.dispose());

  Future<void> mount(
    WidgetTester tester, {
    bool error = false,
    TextEditingController? replacement,
    double width = 300,
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: VerificationCodeField(
                  controller: replacement ?? controller,
                  hasError: error,
                  onSubmitted: () => submissions++,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'one labelled editor owns keyboard/autofill; six slots are decorative',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await mount(tester);
      expect(find.byType(EditableText), findsOneWidget);
      final widget = tester.widget<TextField>(find.byKey(field));
      expect(widget.controller, same(controller));
      expect(widget.autofillHints, [AutofillHints.oneTimeCode]);
      expect(widget.keyboardType, TextInputType.number);
      expect(widget.textInputAction, TextInputAction.done);
      var fields = 0;
      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.flagsCollection.isTextField) {
          fields++;
          expect(data.label, contains('Verification code'));
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .single
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(fields, 1);
      for (var i = 0; i < 6; i++) {
        expect(digit(tester, i), '');
        expect(
          find.ancestor(of: box(i), matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'typing, full code, filtering, leading zeros and backspace stay synchronized',
    (tester) async {
      await mount(tester);
      for (final text in ['1', '123', '123456', '001234', '00', '']) {
        await tester.enterText(find.byKey(field), text);
        await tester.pump();
        expect(controller.text, text);
        expect(List.generate(6, (i) => digit(tester, i)).join(), text);
        expect(submissions, 0);
      }
      await tester.enterText(find.byKey(field), 'x00-12a34567');
      await tester.pump();
      expect(controller.text, '001234');
      expect(List.generate(6, (i) => digit(tester, i)).join(), '001234');
    },
  );

  testWidgets(
    'native paste and platform editing updates fill the boxes without submission',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byKey(field));
      await tester.pump();
      expect(controller.selection.isValid, isTrue);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return {'text': '001234'};
            if (call.method == 'Clipboard.hasStrings') return {'value': true};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.runAsync(
        () => Clipboard.setData(const ClipboardData(text: '001234')),
      );
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      await tester.runAsync(
        () => editor.pasteText(SelectionChangedCause.toolbar),
      );
      await tester.pump();
      expect(controller.text, '001234');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '654321',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      expect(List.generate(6, (i) => digit(tester, i)).join(), '654321');
      expect(submissions, 0);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submissions, 1);
    },
  );

  testWidgets(
    'native selection controls active slot and end tap; blur preserves value',
    (tester) async {
      await mount(tester);
      await tester.enterText(find.byKey(field), '123456');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '123456',
          selection: TextSelection(baseOffset: 1, extentOffset: 3),
        ),
      );
      await tester.pump();
      expect(
        (decoration(tester, 3).border! as Border).top.color,
        NumberInboxPalette.interactiveAccent,
      );
      await tester.tap(find.byKey(field));
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 6));
      expect(
        (decoration(tester, 5).border! as Border).top.color,
        NumberInboxPalette.interactiveAccent,
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '129456',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      expect(digit(tester, 2), '9');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(controller.text, '129456');
      expect(
        (decoration(tester, 3).border! as Border).top.color,
        isNot(NumberInboxPalette.interactiveAccent),
      );
    },
  );

  testWidgets(
    'error rebuild and retry retain controller; unmount does not dispose it',
    (tester) async {
      await mount(tester);
      await tester.enterText(find.byKey(field), '123456');
      await mount(tester, error: true);
      final color = Theme.of(tester.element(box(0))).colorScheme.error;
      for (var i = 0; i < 6; i++) {
        expect((decoration(tester, i).border! as Border).top.color, color);
      }
      expect(controller.text, '123456');
      await mount(tester);
      await tester.enterText(find.byKey(field), '654321');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submissions, 1);
      await tester.pumpWidget(const SizedBox());
      controller.text = '111111';
      expect(tester.takeException(), isNull);
      await mount(tester);
      expect(List.generate(6, (i) => digit(tester, i)).join(), '111111');
    },
  );

  testWidgets('controller replacement detaches the prior controller listener', (
    tester,
  ) async {
    await mount(tester);
    final replacement = TextEditingController(text: '123456');
    await mount(tester, replacement: replacement);
    controller.text = '000000';
    await tester.pump();
    expect(List.generate(6, (i) => digit(tester, i)).join(), '123456');
    await tester.pumpWidget(const SizedBox());
    replacement.dispose();
  });

  for (final width in [272.0, 600.0]) {
    testWidgets('fits width $width with 200% text and RTL', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester, width: width, scale: 2, direction: TextDirection.rtl);
      await tester.enterText(find.byKey(field), '001234');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(box(0)).dx,
        lessThan(tester.getTopLeft(box(5)).dx),
      );
      expect(tester.getSize(box(0)).width, closeTo((width - 40) / 6, 0.1));
      expect(tester.getSize(box(0)).height, greaterThanOrEqualTo(56));
    });
  }
}
