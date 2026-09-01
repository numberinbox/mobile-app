import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
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
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinagoraSysColors.material().linearGradientStartingPage,
        ),
        child: Stack(
          children: [
            // Logo + description centered
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SvgPicture.asset(
                        'assets/images/ic_numberinbox_logo.svg',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Number',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              fontFamily: 'Inter',
                            ),
                          ),
                          TextSpan(
                            text: 'Inbox',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2196F3),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // OTP form + privacy at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: GetBuilder<TwakeWelcomeController>(
                  builder: (ctrl) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ctrl.phase == OtpPhase.phone) ...[
                        _buildPhoneRow(context, ctrl),
                        const SizedBox(height: 16),
                        _buildSendCodeButton(context, ctrl),
                      ] else ...[
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
                      Text(
                        'By continuing, you are agreeing to our',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: LinagoraSysColors.material().outlineVariantDark,
                        ),
                      ),
                      InkWell(
                        onTap: () => AppUtils.launchLink(AppConfig.linagoraPrivacyUrl),
                        child: Text(
                          'Privacy policy',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: LinagoraSysColors.material().primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              borderRadius: BorderRadius.circular(4),
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
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendCodeButton(BuildContext context, TwakeWelcomeController ctrl) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('otp_send_cta'),
        onPressed: ctrl.sending ? null : () => ctrl.sendCode(),
        child: ctrl.sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Send code'),
      ),
    );
  }

  Widget _buildCodeField(BuildContext context, TwakeWelcomeController ctrl) {
    return TextField(
      key: const Key('otp_code_field'),
      controller: ctrl.codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(
        labelText: 'Verification code',
        hintText: '123456',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context, TwakeWelcomeController ctrl) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('otp_verify_cta'),
        onPressed: ctrl.verifying ? null : () => ctrl.verifyCode(),
        child: ctrl.verifying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Verify'),
      ),
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
