import 'package:core/presentation/resources/image_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class ApplicationLogoWidthTextWidget extends StatelessWidget {

  final ImagePaths _imagePaths = Get.find<ImagePaths>();

  final VoidCallback? onTapAction;
  final EdgeInsetsGeometry? margin;
  final double? iconSize;

  ApplicationLogoWidthTextWidget({
    super.key,
    this.onTapAction,
    this.margin,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final logoHeight = iconSize ?? 44;
    final logo = Semantics(
      label: 'NumberInbox',
      image: true,
      child: SvgPicture.asset(
        _imagePaths.icLogoWithText,
        width: logoHeight * 1600 / 360,
        height: logoHeight,
        fit: BoxFit.contain,
      ),
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTapAction == null
          ? logo
          : InkWell(onTap: onTapAction, child: logo),
    );
  }
}
