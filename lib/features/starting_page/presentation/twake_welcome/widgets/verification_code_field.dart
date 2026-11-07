import 'dart:math' as math;

import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six visual slots over one native editor, keeping paste/autofill and semantics.
class VerificationCodeField extends StatefulWidget {
  const VerificationCodeField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.hasError = false,
    this.fieldKey = const Key('otp_code_field'),
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final bool hasError;
  final Key fieldKey;

  @override
  State<VerificationCodeField> createState() => _VerificationCodeFieldState();
}

class _VerificationCodeFieldState extends State<VerificationCodeField> {
  final _focusNode = FocusNode();
  late Listenable _changes;

  @override
  void initState() {
    super.initState();
    _changes = Listenable.merge([widget.controller, _focusNode]);
  }

  @override
  void didUpdateWidget(covariant VerificationCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _changes = Listenable.merge([widget.controller, _focusNode]);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = math.max(
      56.0,
      MediaQuery.textScalerOf(context).scale(24) * 1.3 + 16,
    );
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: Text(
            'Verification code',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: NumberInboxPalette.navy,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the 6-digit code from your SMS.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextField(
                    key: widget.fieldKey,
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    expands: true,
                    maxLines: null,
                    showCursor: false,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 24,
                    ),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      labelStyle: TextStyle(color: Colors.transparent),
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      counterText: '',
                    ),
                    onTapAlwaysCalled: true,
                    onTap: () =>
                        widget.controller.selection = TextSelection.collapsed(
                          offset: widget.controller.text.length,
                        ),
                    onSubmitted: (_) => widget.onSubmitted(),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _changes,
                        builder: (context, _) {
                          final value = widget.controller.value;
                          final active = value.selection.isValid
                              ? value.selection.extentOffset.clamp(0, 5)
                              : value.text.length.clamp(0, 5);
                          return Row(
                            children: [
                              for (var i = 0; i < 6; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    key: ValueKey('otp_digit_box_$i'),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: widget.hasError
                                            ? errorColor
                                            : _focusNode.hasFocus && i == active
                                            ? NumberInboxPalette
                                                  .interactiveAccent
                                            : const Color(0xFFCBD5E1),
                                        width:
                                            _focusNode.hasFocus && i == active
                                            ? 2
                                            : 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      i < value.text.length
                                          ? value.text[i]
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        height: 1.2,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                        color: NumberInboxPalette.navy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
