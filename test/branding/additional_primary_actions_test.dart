import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/state/failure.dart';
import 'package:core/presentation/state/success.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:core/presentation/views/dialog/edit_text_dialog_builder.dart';
import 'package:dartz/dartz.dart' show Either, Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:tmail_ui_user/features/identity_creator/presentation/identity_creator_controller.dart';
import 'package:tmail_ui_user/features/identity_creator/presentation/widgets/identity_creator_form_bottom_view.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/model/identity_action_type.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/forward/widgets/autocomplete_contact_text_field_with_tags.dart';
import 'package:tmail_ui_user/features/manage_account/domain/state/get_all_identities_state.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/advanced_filter_controller.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/controller/input_field_focus_manager.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/search/search_email_filter.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/widgets/advanced_search/advanced_search_filter_form_bottom_view.dart';
import 'package:tmail_ui_user/features/search/email/domain/notifier/search_filter_notifier.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/model/mailbox_node.dart';
import 'package:tmail_ui_user/features/mailbox/presentation/widgets/empty_mailbox_dialog_overlay.dart';

import 'fixtures/brand_widget_test_support.dart';

class _IdentityController extends GetxController
    implements IdentityCreatorController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  ResponsiveUtils get responsiveUtils => ResponsiveUtils();
  @override
  final actionType = IdentityActionType.create.obs;
  @override
  final isDefaultIdentitySupported = false.obs;
  @override
  final viewState = Rx<Either<Failure, Success>>(Right(UIState.idle));
  int saves = 0;
  @override
  void createNewIdentity(BuildContext context) => saves++;
}

class _AdvancedController extends GetxController
    implements AdvancedFilterController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  ImagePaths get imagePaths => ImagePaths();
  int searches = 0;
  @override
  void applyAdvancedSearchFilter({
    required SearchEmailFilter committedFilter,
    required SearchFilterNotifier filterNotifier,
  }) => searches++;
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<ResponsiveUtils>(ResponsiveUtils());
    Get.put<ImagePaths>(ImagePaths());
  });
  tearDown(Get.reset);

  for (final action in IdentityActionType.values) {
    testWidgets(
      'identity ${action.name} gradient invokes the original action',
      (tester) async {
        final controller = _IdentityController()..actionType.value = action;
        await pumpAction(
          tester,
          (_) => IdentityCreatorFormBottomView(controller: controller),
        );
        expect(primaryFill, findsOneWidget);
        await tester.tap(find.byKey(const Key('save_identity_button')));
        expect(controller.saves, 1);
        controller.viewState.value = Right(GetAllIdentitiesLoading());
        await tester.pump();
        expect(primaryFill, findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(controller.saves, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'advanced Search paints its gradient and applies the filter once',
    (tester) async {
      final controller =
          Get.put<AdvancedFilterController>(_AdvancedController())
              as _AdvancedController;
      final focus = InputFieldFocusManager();
      addTearDown(focus.dispose);
      await pumpAction(
        tester,
        (_) => ProviderScope(
          child: AdvancedSearchFilterFormBottomView(focusManager: focus),
        ),
      );
      expect(primaryFill, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey(UiKeys.advancedSearchSearchButton)),
      );
      expect(controller.searches, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('forwarding Add recipient keeps validation and its callback', (
    tester,
  ) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    final results = <List<EmailAddress>>[];
    await pumpAction(
      tester,
      (_) => AutocompleteContactTextFieldWithTags(
        listEmailAddress: const [],
        internalDomain: 'example.com',
        controller: input,
        hasAddContactButton: true,
        onAddContactCallback: results.add,
      ),
    );
    expect(primaryFill, findsOneWidget);
    await tester.enterText(find.byType(TextField), 'friend@example.com');
    await tester.tap(
      find.descendant(of: primaryFill, matching: find.byType(Text)),
    );
    await tester.pumpAndSettle();
    expect(results, [
      [EmailAddress(null, 'friend@example.com')],
    ]);
    expect(input.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('positive edit dialog gradient retains input and callback', (
    tester,
  ) async {
    final results = <String>[];
    await pumpAction(
      tester,
      (_) => EditTextDialogBuilder(
        title: 'Edit',
        value: 'Original',
        positiveText: 'Save',
        negativeText: 'Cancel',
        onPositiveButtonAction: results.add,
      ),
    );
    expect(primaryFill, findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Updated');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(results, ['Updated']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'empty mailbox action retains its selected mailbox and callback',
    (tester) async {
      final node = MailboxNode.root();
      final results = <MailboxNode>[];
      await pumpAction(
        tester,
        (_) => EmptyMailboxDialogOverlay(
          mailboxNode: node,
          onEmptyMailboxActionCallback: results.add,
          onCancelActionClick: () {},
        ),
      );
      expect(primaryFill, findsOneWidget);
      final label = find.descendant(
        of: primaryFill,
        matching: find.byType(Text),
      );
      expect(
        tester.widget<Text>(label).style?.color,
        NumberInboxPalette.primaryActionForeground,
      );
      await tester.tap(label);
      expect(results, [node]);
    },
  );
}
