
import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

class ComposeButtonWidget extends StatelessWidget {

  final ImagePaths imagePaths;
  final VoidCallback onTapAction;
  final EdgeInsetsGeometry? padding;
  final double? width;

  const ComposeButtonWidget({
    super.key,
    required this.imagePaths,
    required this.onTapAction,
    this.padding,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final primaryActionStyle = LinagoraSidebarButtonStyles.primaryAction(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedPadding = padding ?? const EdgeInsetsDirectional.only(
      start: 16,
      end: 16,
      top: 16,
      bottom: 8,
    );
    final horizontalPadding = resolvedPadding
        .resolve(Directionality.of(context))
        .horizontal;
    final defaultWidth = ResponsiveUtils.sidebarMenuWidth - horizontalPadding;
    final resolvedWidth = width ?? (defaultWidth < 0 ? 0 : defaultWidth);

    if (isDark) {
      return LinagoraSidebarPrimaryAction(
        label: AppLocalizations.of(context).compose,
        onPressed: onTapAction,
        buttonKey: const Key(UiKeys.composeEmailPrimaryAction),
        iconSpacing: LinagoraSidebarButtonStyles.primaryActionIconSpacing,
        outerPadding: resolvedPadding,
        width: resolvedWidth,
        alignment: AlignmentDirectional.centerStart,
        style: primaryActionStyle,
        iconWidget: SvgPicture.asset(
          imagePaths.icPenNoBorder,
          width: 12,
          height: 12,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        ),
      );
    }

    final style = primaryActionStyle.copyWith(
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: const WidgetStatePropertyAll(
        NumberInboxPalette.primaryActionForeground,
      ),
    );
    final iconColor = style.foregroundColor?.resolve(const <WidgetState>{})
        ?? NumberInboxPalette.primaryActionForeground;

    return Padding(
      padding: resolvedPadding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: NumberInboxPalette.primaryActionGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: LinagoraSidebarPrimaryAction(
            label: AppLocalizations.of(context).compose,
            onPressed: onTapAction,
            buttonKey: const Key(UiKeys.composeEmailPrimaryAction),
            iconSpacing: LinagoraSidebarButtonStyles.primaryActionIconSpacing,
            width: resolvedWidth,
            style: style,
            iconWidget: SvgPicture.asset(
              imagePaths.icPenNoBorder,
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
