import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/verification_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/branded_action_button.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/app_utils.dart';

class TwakeWelcomeView extends GetWidget<TwakeWelcomeController> {
  const TwakeWelcomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            key: const Key('welcome_brand_mark_slot'),
                            width: 104,
                            height: 104,
                            // The same padded 256-unit canvas as HomeView;
                            // only its ~100-unit artwork occupies this slot.
                            child: OverflowBox(
                              minWidth: 256, maxWidth: 256,
                              minHeight: 256, maxHeight: 256,
                              child: Image.asset(
                                'assets/splash/numberinbox_splash_mark.png',
                                width: 256, height: 256,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/images/numberinbox_wordmark.svg',
                          semanticsLabel: 'NumberInbox',
                          width: 244,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Email, reimagined with your number.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: NumberInboxPalette.navy,
                          ),
                        ),
                        const Spacer(flex: 2),
                        GetBuilder<TwakeWelcomeController>(
                          builder: (ctrl) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (ctrl.phase == OtpPhase.phone) ...[
                                _buildPhaseHeading('Enter your phone number'),
                                const SizedBox(height: 16),
                                _buildPhoneRow(context, ctrl),
                                const SizedBox(height: 16),
                                _buildSendCodeButton(context, ctrl),
                              ] else ...[
                                _buildVerificationDestination(context, ctrl),
                                const SizedBox(height: 12),
                                _buildCodeField(context, ctrl),
                                const SizedBox(height: 16),
                                _buildVerifyButton(context, ctrl),
                              ],
                              if (ctrl.error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  ctrl.error!,
                                  key: const Key('otp_error'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              const Text(
                                'By continuing, you are agreeing to our',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: NumberInboxPalette.navy,
                                ),
                              ),
                              InkWell(
                                onTap: () => AppUtils.launchLink(AppConfig.linagoraPrivacyUrl),
                                child: const Text(
                                  'Privacy policy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: NumberInboxPalette.interactiveAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseHeading(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: NumberInboxPalette.navy,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildVerificationDestination(
    BuildContext context,
    TwakeWelcomeController ctrl,
  ) {
    final destination = ctrl.otpDestination;
    return Column(
      children: [
        _buildPhaseHeading('Verify your number'),
        if (destination != null) ...[
          const SizedBox(height: 8),
          const Text(
            'We sent a 6-digit code to',
            textAlign: TextAlign.center,
            style: TextStyle(color: NumberInboxPalette.navy),
          ),
          Text(
            _formatDestination(destination),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: NumberInboxPalette.navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        TextButton(
          key: const Key('otp_change_phone_number'),
          style: TextButton.styleFrom(
            foregroundColor: NumberInboxPalette.interactiveAccent,
            minimumSize: const Size(0, 48),
          ),
          onPressed: ctrl.verifying
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  ctrl.changePhoneNumber();
                },
          child: const Text(
            'Change phone number',
            textAlign: TextAlign.center,
            style: TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  String _formatDestination(String e164) {
    try {
      final phoneUtil = PhoneNumberUtil.instance;
      return phoneUtil.format(
        phoneUtil.parse(e164, ''),
        PhoneNumberFormat.international,
      );
    } on NumberParseException {
      return e164;
    }
  }

  Widget _buildPhoneRow(BuildContext context, TwakeWelcomeController ctrl) {
    return Row(
      children: [
        GestureDetector(
          key: const Key('otp_country_picker'),
          onTap: () => _showCountryPicker(context, ctrl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctrl.selectedCountry.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 2),
                Text(ctrl.selectedCountry.dialCode, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('otp_phone_field'),
            controller: ctrl.phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Phone number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendCodeButton(BuildContext context, TwakeWelcomeController ctrl) {
    return BrandedActionButton(
      buttonKey: const Key('otp_send_cta'),
      label: 'Send code',
      isLoading: ctrl.sending,
      onPressed: ctrl.sendCode,
    );
  }

  Widget _buildCodeField(BuildContext context, TwakeWelcomeController ctrl) {
    return VerificationCodeField(
      controller: ctrl.codeController,
      hasError: ctrl.error != null,
      onSubmitted: ctrl.verifyCode,
    );
  }

  Widget _buildVerifyButton(BuildContext context, TwakeWelcomeController ctrl) {
    return BrandedActionButton(
      buttonKey: const Key('otp_verify_cta'),
      label: 'Verify',
      isLoading: ctrl.verifying,
      onPressed: ctrl.verifyCode,
    );
  }

  void _showCountryPicker(BuildContext context, TwakeWelcomeController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CountryPickerSheet(
        selectedCountry: ctrl.selectedCountry,
        onSelected: (country) {
          ctrl.onCountrySelected(country);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onSelected,
  });

  final Country selectedCountry;
  final void Function(Country) onSelected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  List<Country> get _filtered {
    if (_query.isEmpty) return countries;
    final q = _query.toLowerCase();
    return countries.where((c) =>
      c.name.toLowerCase().contains(q) ||
      c.dialCode.contains(q) ||
      c.code.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('country_search'),
                decoration: const InputDecoration(
                  hintText: 'Search country...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final c = _filtered[index];
                  final selected = c.code == widget.selectedCountry.code;
                  return ListTile(
                    key: Key('country_${c.code}'),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(c.name),
                    subtitle: Text(c.dialCode),
                    trailing: selected
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => widget.onSelected(c),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
