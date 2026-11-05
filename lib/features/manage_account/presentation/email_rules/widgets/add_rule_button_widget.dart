import 'package:core/presentation/resources/image_paths.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:core/presentation/views/button/tmail_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:tmail_ui_user/main/localizations/app_localizations.dart';

typedef OnAddRuleAction = void Function();

class AddRuleButtonWidget extends StatelessWidget {
  final ImagePaths imagePaths;
  final OnAddRuleAction onAddRuleAction;
  final EdgeInsetsGeometry? margin;
  final double minWidth;

  const AddRuleButtonWidget({
    super.key,
    required this.imagePaths,
    required this.onAddRuleAction,
    this.margin,
    this.minWidth = 161,
  });

  @override
  Widget build(BuildContext context) {
    return TMailButtonWidget(
      text: AppLocalizations.of(context).addARule,
      icon: imagePaths.icAddIdentity,
      backgroundGradient: NumberInboxPalette.primaryActionGradient,
      borderRadius: 100,
      height: 48,
      maxWidth: 300,
      minWidth: minWidth,
      margin: margin,
      textStyle: ThemeUtils.textStyleM3LabelLarge(color: NumberInboxPalette.primaryActionForeground),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 32,
      ),
      iconSize: 16,
      iconColor: NumberInboxPalette.primaryActionForeground,
      iconSpace: 8,
      maxLines: 1,
      flexibleText: true,
      textOverflow: TextOverflow.ellipsis,
      mainAxisSize: MainAxisSize.min,
      onTapActionCallback: onAddRuleAction,
    );
  }
}
