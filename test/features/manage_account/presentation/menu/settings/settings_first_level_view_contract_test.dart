// integration_test/numberinbox depends on these keys; renaming one breaks the release gate.
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations_delegate.dart';
import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/quotas/quota.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/menu/settings/settings_controller.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/menu/settings/settings_first_level_view.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';

class _Dashboard extends GetxController implements ManageAccountDashBoardController {
  final supported = false.obs;
  @override
  final ownEmailAddress = 'synthetic@example.test'.obs;
  @override
  final accountId = Rxn<AccountId>();
  @override
  final octetsQuota = Rxn<Quota>();
  @override
  Session? get sessionCurrent => null;
  @override
  final twakeAppManager = TwakeAppManager();
  @override
  bool get isRuleFilterCapabilitySupported => supported.value;
  @override
  bool get isServerSettingsCapabilitySupported => supported.value;
  @override
  bool get isForwardCapabilitySupported => supported.value;
  @override
  bool get isVacationCapabilitySupported => supported.value;
  @override
  bool get isLanguageSettingDisplayed => supported.value;
  @override
  bool get isFcmCapabilitySupported => supported.value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(Get.reset);
  testWidgets('mobile settings exposes the tappable deletion selector', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    Get.testMode = true;
    Get.put<ManageAccountDashBoardController>(_Dashboard());
    Get.put(ResponsiveUtils());
    Get.put(ImagePaths());
    Get.put(SettingsController());
    await tester.pumpWidget(const MaterialApp(localizationsDelegates: [AppLocalizationsDelegate(), GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], home: Scaffold(body: SettingsFirstLevelView())));
    await tester.pumpAndSettle();
    final finder = find.byKey(const Key('setting_delete_account'));
    await tester.ensureVisible(finder);
    expect(tester.widget<ListTile>(finder).onTap, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
