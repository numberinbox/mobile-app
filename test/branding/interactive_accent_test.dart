import 'dart:convert';
import 'dart:io';

import 'package:core/presentation/extensions/color_extension.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/utils/html/file_link_card_html_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/numberinbox/theme/numberinbox_colors.dart';

String _assetFingerprint(String text) {
  // FNV-1a checks that artwork content survives this color-only migration.
  var fingerprint = 0x811c9dc5;
  for (final byte in utf8.encode(text)) {
    fingerprint = ((fingerprint ^ byte) * 0x01000193) & 0xffffffff;
  }
  return fingerprint.toRadixString(16).padLeft(8, '0');
}

void main() {
  const teal = Color(0xFF0B7A94);

  test('legacy aliases and themes resolve to the selected teal accent', () {
    expect(NumberInboxPalette.actionGreen, teal);
    for (final alias in [
      AppColor.primaryColor,
      AppColor.primaryMain,
      AppColor.primaryLinShare,
      AppColor.m3Primary,
      AppColor.appColor,
      AppColor.avatarTextColor,
      AppColor.colorActionCancelDialog,
      AppColor.colorComposeButton,
      AppColor.colorExpandMailbox,
      AppColor.colorFilterMessageEnabled,
      AppColor.colorInvitedEventActionText,
      AppColor.colorTextButton,
      AppColor.counterMailboxColor,
      AppColor.enableSendEmailButtonColor,
      AppColor.loginTextFieldFocusedBorder,
      AppColor.mailboxSelectedIconColor,
      AppColor.mailboxSelectedTextColor,
      AppColor.subjectEmailTextColorUnRead,
      AppColor.textFieldFocusedBorderColor,
      NumberInboxColors.primary,
    ]) {
      expect(alias, teal);
    }
    expect(
      AppColor.colorShadowComposerButton,
      teal.withValues(alpha: 0x99 / 255),
    );
    for (final theme in [
      ThemeUtils.buildAppTheme(),
      NumberInboxColors.theme(),
    ]) {
      expect(theme.colorScheme.primary, teal);
      expect(
        (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
            .borderSide
            .color,
        teal,
      );
    }
    final selection = ThemeUtils.buildAppTheme().textSelectionTheme;
    expect(selection.cursorColor, teal);
    expect(selection.selectionHandleColor, teal);
    expect(selection.selectionColor, NumberInboxPalette.selection);
  });

  test('the full primary gradient supports white labels', () {
    final colors = NumberInboxPalette.primaryActionGradient.colors;
    for (var i = 0; i <= 100; i++) {
      final progress = i / 50;
      final segment = progress < 1 ? 0 : 1;
      final color = Color.lerp(
        colors[segment],
        colors[segment + 1],
        progress - segment,
      )!;
      expect(
        1.05 / (color.computeLuminance() + 0.05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('all inventoried SVGs change only the legacy RGB color', () {
    final manifest =
        jsonDecode(
              File(
                'test/branding/legacy_green_svg_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(manifest, hasLength(111));
    for (final entry in manifest.entries) {
      final actual = File(entry.key).readAsStringSync();
      expect(
        actual.toUpperCase(),
        isNot(contains('#047857')),
        reason: entry.key,
      );
      expect(actual.toUpperCase(), contains('#0B7A94'), reason: entry.key);
      final restored = actual.replaceAll(
        RegExp('#0B7A94', caseSensitive: false),
        '#047857',
      );
      expect(
        _assetFingerprint(restored),
        entry.value,
        reason: 'Only RGB can change in ${entry.key}',
      );
    }
  });

  test('Android controls and worker action text use the selected teal', () {
    expect(
      File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
      contains('<color name="colorPrimary">#0B7A94</color>'),
    );
    expect(
      File('web/worker_service/style.css').readAsStringSync(),
      contains('color: #0B7A94;'),
    );
  });

  test('attachment card action uses teal without changing escaping', () {
    final html = FileLinkCardHtmlBuilder.buildFileLinkCard(
      const FileLinkCardContent(
        href: 'https://example.com/file',
        title: '<test>',
        actionLabel: 'Open',
        iconZoneHtml: '',
      ),
    );
    expect(html.toUpperCase(), contains('COLOR:#0B7A94;'));
    expect(html, contains('&lt;test&gt;'));
    expect(html, contains('rel="noopener noreferrer"'));
  });
}
