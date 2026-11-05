import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/views/container/tmail_container_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tmail_ui_user/features/base/model/ui_keys.dart';
import 'package:tmail_ui_user/features/composer/presentation/styles/mobile_app_bar_composer_widget_style.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

class MobileComposerSendButton extends StatelessWidget {
  const MobileComposerSendButton({
    super.key,
    required this.imagePaths,
    required this.isEnabled,
    required this.onTap,
  });

  final ImagePaths imagePaths;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = MobileAppBarComposerWidgetStyle.sendButtonIconSize;
    final icon = SvgPicture.asset(
      isEnabled ? imagePaths.icSendMobileArrow : imagePaths.icSendDisable,
      width: size,
      height: size,
      fit: BoxFit.fill,
      colorFilter: isEnabled
          ? const ColorFilter.mode(
              NumberInboxPalette.primaryActionForeground,
              BlendMode.srcIn,
            )
          : null,
    );
    return TMailContainerWidget(
      key: const ValueKey(UiKeys.sendEmailButton),
      backgroundColor: Colors.transparent,
      padding: MobileAppBarComposerWidgetStyle.iconPadding,
      tooltipMessage: AppLocalizations.of(context).send,
      // The composer controller handles taps in either visual state.
      onTapActionCallback: onTap,
      child: isEnabled
          ? Stack(
              alignment: Alignment.center,
              children: [
                // Match the 36-unit circle in the original 40-unit icon.
                const SizedBox.square(
                  dimension: size * 36 / 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: NumberInboxPalette.primaryActionGradient,
                    ),
                  ),
                ),
                icon,
              ],
            )
          : icon,
    );
  }
}
