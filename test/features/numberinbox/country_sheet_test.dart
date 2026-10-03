import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/numberinbox/country_picker_sheet.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:tmail_ui_user/main/localizations/localization_service.dart';

void main() {
  Future<EmailAddress? Function()> pumpOpener(
    WidgetTester tester,
    EmailAddress recipient,
  ) async {
    EmailAddress? resolved;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resolved = await resolvePhoneRecipient(context, recipient);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    EmailAddress? readResult() => resolved;
    return readResult;
  }

  Future<void> searchCountry(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const Key('country_search')),
      query,
    );
    await tester.pumpAndSettle();
  }

  group('resolvePhoneRecipient', () {
    testWidgets('shows raw number and name with no preselected country',
        (tester) async {
      final readResult = await pumpOpener(
        tester,
        EmailAddress('Somluck', '029009119'),
      );

      expect(find.text('029009119'), findsOneWidget);
      expect(find.text('Somluck'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(readResult(), isNull);
    });

    testWidgets('invalid country shows inline error and keeps sheet open',
        (tester) async {
      final readResult = await pumpOpener(
        tester,
        EmailAddress('Somluck', '029009119'),
      );

      await searchCountry(tester, 'United States');
      await tester.tap(find.byKey(const Key('country_US')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('country_validation_error')), findsOneWidget);
      expect(find.byKey(const Key('country_US')), findsOneWidget);
      await searchCountry(tester, 'Thailand');
      expect(find.byKey(const Key('country_TH')), findsOneWidget);
      expect(readResult(), isNull);
    });

    testWidgets('valid country returns the resolved recipient and closes',
        (tester) async {
      final readResult = await pumpOpener(
        tester,
        EmailAddress('Somluck', '029009119'),
      );

      await searchCountry(tester, 'Thailand');
      await tester.tap(find.byKey(const Key('country_TH')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('country_TH')), findsNothing);
      expect(readResult()?.email, '+6629009119@numberinbox.com');
      expect(readResult()?.name, 'Somluck');
    });

    testWidgets('dismissal cancels with null', (tester) async {
      final readResult = await pumpOpener(
        tester,
        EmailAddress('Somluck', '029009119'),
      );

      expect(find.byKey(const Key('country_TH')), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('country_TH')), findsNothing);
      expect(readResult(), isNull);
    });

    testWidgets('country rows expose tap actions', (tester) async {
      await pumpOpener(tester, EmailAddress('Somluck', '029009119'));

      await searchCountry(tester, 'Thailand');
      final semantics = tester.getSemantics(find.byKey(const Key('country_TH')));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });
  });

  group('CountryPickerSheet existing behavior', () {
    testWidgets('preselected country still shows a check mark', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CountryPickerSheet(
            selectedCountry: thailand,
            onSelected: _ignoreCountry,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('tapping a country still selects and reports it', (tester) async {
      Country? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CountryPickerSheet(
            selectedCountry: thailand,
            onSelected: (country) => selected = country,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await searchCountry(tester, 'United States');
      await tester.tap(find.byKey(const Key('country_US')));
      await tester.pumpAndSettle();

      expect(selected?.code, 'US');
    });
  });
}

void _ignoreCountry(_) {}

const thailand = Country(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭');
