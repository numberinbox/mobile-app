import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:core/presentation/utils/theme_utils.dart';
import 'package:flutter/material.dart';

/// The NumberInbox primary action used by the welcome flow.
///
/// Both OTP phases share this button so **Send code** and **Verify** keep the
/// same gradient, geometry, radius, and loading treatment. The gradient is
/// painted by an ancestor [DecoratedBox] while the [FilledButton] itself stays
/// transparent, which keeps Material semantics, focus, and the clipped ripple
/// without covering the brand colors with an opaque surface.
class BrandedActionButton extends StatelessWidget {
  const BrandedActionButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
  });

  /// Applied to the inner [FilledButton] so existing finders and accessibility
  /// lookups that target the tappable button keep working.
  final Key? buttonKey;

  final String label;
  final VoidCallback? onPressed;

  /// Shows the white progress indicator and suppresses taps.
  final bool isLoading;

  /// A disabled, non-loading button drops to a neutral fill instead of
  /// leaving a saturated gradient behind an inactive control.
  final bool isEnabled;

  static const double minHeight = 54;
  static const double radius = 14;
  static const double spinnerSize = 20;
  static const Color _disabledFill = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    // Loading only suppresses interaction: the brand gradient stays so the
    // white progress indicator keeps its contrast. The neutral fill is
    // reserved for a genuinely disabled, non-loading control.
    final isDisabledFill = !isEnabled && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDisabledFill
              ? const [_disabledFill, _disabledFill]
              : const [
                  NumberInboxPalette.actionGreen,
                  NumberInboxPalette.actionBlue,
                ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(
        width: double.infinity,
        height: minHeight,
        child: FilledButton(
          key: buttonKey,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(minHeight),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          onPressed: isEnabled && !isLoading ? onPressed : null,
          child: isLoading
              ? const SizedBox(
                  width: spinnerSize,
                  height: spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: ThemeUtils.defaultTextStyleInterFont.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}