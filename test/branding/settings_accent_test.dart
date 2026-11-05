import 'dart:io';

import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/menu/widgets/account_menu_item_tile_builder.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/menu/widgets/setting_first_level_tile_builder.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/model/account_menu_item.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/profile_setting/popup_menu_item_profile_setting_type_action.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/presentation/model/profile_setting/profile_setting_action_type.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

import 'fixtures/brand_widget_test_support.dart';

void main() {
  final images = ImagePaths();
  final items = AccountMenuItem.values.where(
    (item) => item != AccountMenuItem.none,
  );

  setUp(() {
    Get.testMode = true;
    Get.put<ResponsiveUtils>(ResponsiveUtils());
    Get.put<ImagePaths>(images);
  });
  tearDown(Get.reset);

  for (final item in items) {
    testWidgets('settings row and wider menu use teal for ${item.name}', (
      tester,
    ) async {
      var calls = 0;
      final path = item.getIcon(images);
      await pumpAction(
        tester,
        (_) => SettingFirstLevelTileBuilder('Setting', path, () => calls++),
        size: const Size(320, 640),
      );
      final glyph = find.byWidgetPredicate(
        (widget) =>
            widget is SvgPicture &&
            widget.bytesLoader is SvgAssetLoader &&
            (widget.bytesLoader as SvgAssetLoader).assetName == path,
      );
      expect(glyph, findsOneWidget);
      expect(tester.widget<SvgPicture>(glyph).colorFilter, isNull);
      expect(File(path).readAsStringSync().toUpperCase(), contains('#0B7A94'));
      await tester.tap(find.text('Setting'));
      expect(calls, 1);

      await pumpAction(
        tester,
        (_) => AccountMenuItemTileBuilder(
          imagePaths: images,
          responsiveUtils: ResponsiveUtils(),
          menuItem: item,
          onSelectAccountMenuItemAction: (selected) {
            expect(selected, item);
            calls++;
          },
        ),
        size: const Size(1024, 768),
      );
      expect(
        tester.widget<SvgPicture>(glyph).colorFilter,
        const ColorFilter.mode(Color(0xFF0B7A94), BlendMode.srcIn),
      );
      await tester.tap(glyph);
      expect(calls, 2);
    });
  }

  testWidgets('profile popover keeps its gray icon override', (tester) async {
    await pumpAction(tester, (context) {
      final action = PopupMenuItemProfileSettingTypeAction(
        ProfileSettingActionType.signOut,
        AppLocalizations.of(context),
        images,
      );
      expect(action.actionIconColor, const Color(0xFF686E76));
      return const SizedBox.shrink();
    });
  });
}
