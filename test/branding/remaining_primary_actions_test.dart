import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:dartz/dartz.dart' show Either, Right;
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/views/dialog/confirm_dialog_button.dart';
import 'package:core/presentation/views/dialog/confirmation_dialog_builder.dart';
import 'package:core/presentation/views/dialog/modal_list_action_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/base/mixin/logout_mixin.dart';
import 'package:tmail_ui_user/features/email/presentation/widgets/email_address_detail_widget.dart';
import 'package:tmail_ui_user/features/email_recovery/presentation/widgets/list_button_widget.dart';
import 'package:tmail_ui_user/features/login/presentation/widgets/try_again_button.dart';
import 'package:tmail_ui_user/features/login/presentation/base_login_view.dart';
import 'package:tmail_ui_user/features/login/presentation/login_controller.dart';
import 'package:tmail_ui_user/features/login/presentation/login_view.dart';
import 'package:tmail_ui_user/features/login/presentation/login_form_type.dart';
import 'package:tmail_ui_user/features/login/domain/model/recent_login_username.dart';
import 'package:tmail_ui_user/features/login/presentation/widgets/horizontal_progress_loading_button.dart';
import 'package:tmail_ui_user/features/composer/presentation/view/web/desktop_edit_recipients_view.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/email_rules/widgets/add_rule_button_widget.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/identities/widgets/create_new_identity_button_widget.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/storage/widgets/upgrade_storage_widget.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/vacation/widgets/vacation_list_action_widget.dart';
import 'package:tmail_ui_user/features/rules_filter_creator/presentation/widgets/rule_filter_list_action_widget.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';

import 'fixtures/brand_widget_test_support.dart';

class _LogoutHost with LogoutMixin {}

class _LoginController extends GetxController implements LoginController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  int calls = 0;
  int nextCalls = 0;
  @override
  final loginFormType = LoginFormType.dnsLookupForm.obs;
  @override
  final viewState = Rx<Either<Failure, Success>>(Right(UIState.idle));
  @override
  final usernameInputController = TextEditingController();
  @override
  bool get isBackButtonActivated =>
      loginFormType.value == LoginFormType.credentialForm;
  @override
  void invokeDNSLookupToGetJmapUrl() => nextCalls++;
  @override
  Future<List<RecentLoginUsername>> getAllRecentLoginUsernameAction(
      {String? pattern}) async => [];
  @override
  void onUsernameChange(String value) {}
  @override
  void selectUsernameFromSuggestion(RecentLoginUsername loginUsername) {}
  @override
  ResponsiveUtils get responsiveUtils => ResponsiveUtils();
  @override
  void handleLoginPressed(BuildContext context) => calls++;
}

class _LoginButtonView extends BaseLoginView {
  const _LoginButtonView();

  @override
  Widget build(BuildContext context) => buildLoginButton(context);
}

void main() {
  final images = ImagePaths();
  setUp(() {
    Get.testMode = true;
    Get.put<ResponsiveUtils>(ResponsiveUtils());
    Get.put<ImagePaths>(images);
  });
  tearDown(Get.reset);

  final cases = <String, Widget Function(VoidCallback)>{
    'Create new identity': (tap) => CreateNewIdentityButtonWidget(
      imagePaths: images,
      onCreateNewIdentityAction: tap,
    ),
    'Add a rule': (tap) =>
        AddRuleButtonWidget(imagePaths: images, onAddRuleAction: tap),
    'Vacation Save changes': (tap) => VacationListActionWidget(
      onConfirmButtonAction: tap,
      onCancelButtonAction: () {},
    ),
    'Restore': (tap) =>
        ListButtonWidget(isMobile: true, onRestore: tap, onCancel: () {}),
    'Rule create and save': (tap) => RuleFilterListActionWidget(
      positiveLabel: 'Save rule',
      negativeLabel: 'Cancel',
      onPositiveAction: tap,
      onNegativeAction: () {},
    ),
    'Upgrade storage': (tap) => UpgradeStorageWidget(
      imagePaths: images,
      isPremiumAvailable: true,
      onUpgradeStorageAction: tap,
    ),
    'Desktop Edit email': (tap) => DesktopEditRecipientsView(
      emailAddress: EmailAddress('Example', 'test@example.com'),
      imagePaths: images,
      width: 400,
      onCopyAction: () {},
      onEditAction: tap,
      onCreateRuleAction: () {},
      onCloseAction: () {},
    ),
    'Compose from address': (tap) => EmailAddressDetailWidget(
      imagePaths: images,
      emailAddress: EmailAddress('Example', 'test@example.com'),
      onComposeEmailAction: (_) => tap(),
    ),
    'Legacy login retry': (tap) =>
        TryAgainButton(onRetry: tap, responsiveUtils: ResponsiveUtils()),
    'Folder and label positive action': (tap) => ModalListActionButtonWidget(
      positiveLabel: 'Apply',
      negativeLabel: 'Cancel',
      onPositiveAction: tap,
      onNegativeAction: () {},
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} paints the primary gradient and calls once', (
      tester,
    ) async {
      var calls = 0;
      await pumpAction(tester, (_) => entry.value(() => calls++));
      expect(primaryFill, findsOneWidget);
      final label = find.descendant(
        of: primaryFill,
        matching: find.byType(Text),
      );
      expect(label, findsOneWidget);
      expect(
        tester.widget<Text>(label).style?.color,
        NumberInboxPalette.primaryActionForeground,
      );
      await tester.tap(label);
      await tester.pump();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy login Sign in retains its key and callback', (
    tester,
  ) async {
    final controller = _LoginController();
    addTearDown(controller.usernameInputController.dispose);
    Get.put<LoginController>(controller);
    await pumpAction(tester, (_) => const _LoginButtonView());
    expect(primaryFill, findsOneWidget);
    await tester.tap(find.byKey(const Key('loginSubmitForm')));
    expect(controller.calls, 1);
  });

  testWidgets('legacy login Next keeps its key and DNS action', (tester) async {
    final controller = _LoginController();
    addTearDown(controller.usernameInputController.dispose);
    Get.put<LoginController>(controller);
    await pumpAction(tester, (_) => const LoginView(), size: const Size(1024, 900));
    expect(primaryFill, findsOneWidget);
    await tester.tap(find.byKey(const Key('nextToCredentialForm')));
    await tester.pump();
    expect(controller.nextCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy login progress retains the gradient while unavailable', (
    tester,
  ) async {
    await pumpAction(
      tester,
      (_) => const HorizontalProgressLoadingButton(),
      settle: false,
    );
    expect(primaryFill, findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      Colors.white,
    );
  });

  for (final confirm in [false, true]) {
    testWidgets('real logout dialog ${confirm ? "confirms" : "cancels"} once', (
      tester,
    ) async {
      var calls = 0;
      await pumpAction(
        tester,
        (context) => TextButton(
          onPressed: () => _LogoutHost().showLogoutConfirmDialog(
            context: context,
            userAddress: 'test@example.com',
            onConfirmAction: () => calls++,
          ),
          child: const Text('Open logout'),
        ),
      );
      await tester.tap(find.text('Open logout'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ConfirmationDialogBuilder));
      final l10n = AppLocalizations.of(context);
      expect(
        find.ancestor(of: find.text(l10n.yesLogout), matching: primaryFill),
        findsOneWidget,
      );
      await tester.tap(find.text(confirm ? l10n.yesLogout : l10n.cancel));
      await tester.pumpAndSettle();
      expect(calls, confirm ? 1 : 0);
      expect(find.byType(ConfirmationDialogBuilder), findsNothing);
    });
  }

  testWidgets(
    'neutral and destructive confirmation overrides keep their fill',
    (tester) async {
      for (final color in [Colors.red, Colors.grey]) {
        await pumpAction(
          tester,
          (_) => ConfirmationDialogBuilder(
            imagePath: images,
            confirmText: 'Confirm',
            cancelText: 'Cancel',
            confirmBackgroundButtonColor: color,
          ),
        );
        expect(primaryFill, findsNothing);
        final control = tester.widget<ConfirmDialogButton>(
          find.widgetWithText(ConfirmDialogButton, 'Confirm'),
        );
        expect(control.backgroundColor, color);
      }
    },
  );

  testWidgets(
    'modal unavailable and progressing variants retain their behavior',
    (tester) async {
      var calls = 0;
      await pumpAction(
        tester,
        (_) => ModalListActionButtonWidget(
          positiveLabel: 'Apply',
          negativeLabel: 'Cancel',
          isPositiveActionEnabled: false,
          onPositiveAction: () => calls++,
          onNegativeAction: () {},
        ),
      );
      expect(primaryFill, findsNothing);
      await tester.tap(find.text('Apply'));
      expect(calls, 0);
      await pumpAction(
        tester,
        (_) => ModalListActionButtonWidget(
          positiveLabel: 'Apply',
          negativeLabel: 'Cancel',
          isProgressing: true,
          onPositiveAction: () => calls++,
          onNegativeAction: () {},
        ),
        settle: false,
      );
      expect(primaryFill, findsOneWidget);
      await tester.tap(primaryFill);
      expect(calls, 0);
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets('identity action fits narrow large text in ${direction.name}', (
      tester,
    ) async {
      await pumpAction(
        tester,
        (_) => CreateNewIdentityButtonWidget(
          imagePaths: images,
          onCreateNewIdentityAction: () {},
        ),
        size: const Size(320, 640),
        direction: direction,
        scale: 2,
      );
      expect(primaryFill, findsOneWidget);
      expect(tester.getSize(primaryFill).height, 48);
      expect(tester.takeException(), isNull);
    });
  }
}
