import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Applies dark status-bar icons to a subtree that paints a light surface.
///
/// Material `AppBar` publishes its own [AnnotatedRegion], but several NumberInbox
/// screens use a custom app bar instead — the mailbox thread view, the welcome
/// screen, the composer. Without a region the platform falls back to white icons,
/// which are invisible on the app's white background.
///
/// This region wraps the whole app, so any screen painting a dark surface must
/// publish its own nested [AnnotatedRegion] to override it. The innermost region
/// covering the status-bar area wins.
class LightSystemUiRegion extends StatelessWidget {
  const LightSystemUiRegion({
    super.key,
    required this.child,
  });

  /// Transparent so the app surface shows through the status-bar area.
  static const SystemUiOverlayStyle style = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: child,
    );
  }
}
