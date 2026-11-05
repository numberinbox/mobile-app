
import 'package:core/presentation/action/action_callback_define.dart';
import 'package:core/presentation/extensions/color_extension.dart';
import 'package:flutter/material.dart';

class TMailContainerWidget extends StatelessWidget {

  final OnTapActionCallback? onTapActionCallback;
  final OnTapActionAtPositionCallback? onTapActionAtPositionCallback;
  final OnLongPressActionCallback? onLongPressActionCallback;

  final Widget child;
  final double borderRadius;
  final double? width;
  final double? height;
  final double maxWidth;
  final double maxHeight;
  final double minWidth;
  final String? tooltipMessage;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final BoxBorder? border;
  final Color? hoverColor;
  final AlignmentGeometry? alignment;

  const TMailContainerWidget({
    super.key,
    required this.child,
    this.onTapActionCallback,
    this.onTapActionAtPositionCallback,
    this.onLongPressActionCallback,
    this.borderRadius = 20,
    this.width,
    this.height,
    this.maxWidth = double.infinity,
    this.maxHeight = double.infinity,
    this.minWidth = 0,
    this.tooltipMessage,
    this.backgroundColor,
    this.backgroundGradient,
    this.padding,
    this.boxShadow,
    this.margin,
    this.border,
    this.hoverColor,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: backgroundGradient == null
          ? backgroundColor ?? AppColor.colorButtonHeaderThread
          : null,
      gradient: backgroundGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border,
      boxShadow: boxShadow,
    );
    final contentPadding = padding ?? const EdgeInsetsDirectional.all(8);
    // Ink includes the decoration's border padding. Keep the dimensions
    // outside it so a gradient cannot enlarge a bordered button.
    final item = Container(
      decoration: backgroundGradient == null ? decoration : null,
      width: width,
      height: height,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        minWidth: minWidth,
      ),
      alignment: backgroundGradient == null ? alignment : null,
      padding: backgroundGradient == null ? contentPadding : null,
      child: backgroundGradient == null
          ? child
          : Ink(
              decoration: decoration,
              child: Container(
                alignment: alignment,
                padding: contentPadding,
                child: child,
              ),
            ),
    );

    final materialChild = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTapActionCallback,
        onTapDown: onTapActionAtPositionCallback != null
          ? (detail) {
              if (onTapActionAtPositionCallback != null) {
                final screenSize = MediaQuery.of(context).size;
                final offset = detail.globalPosition;
                final position = RelativeRect.fromLTRB(
                  offset.dx,
                  offset.dy,
                  screenSize.width - offset.dx,
                  screenSize.height - offset.dy,
                );
                onTapActionAtPositionCallback!.call(position);
              }
            }
          : null,
        hoverColor: hoverColor,
        onLongPress: onLongPressActionCallback,
        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        child: tooltipMessage != null
          ? Tooltip(
              message: tooltipMessage,
              child: item,
            )
          : item
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: materialChild);
    } else {
      return materialChild;
    }
  }
}