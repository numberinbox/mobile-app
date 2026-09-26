import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:core/presentation/resources/numberinbox_palette.dart';
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
                          child: Image.asset(
                            'assets/images/numberinbox_mark.png',
                            width: 104,
                            height: 104,
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
                                    color: NumberInboxPalette.actionBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your number. Your inbox.',
                                style: TextStyle(
                                  color: NumberInboxPalette.actionGreen,
                                  fontWeight: FontWeight.w600,
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
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [
            NumberInboxPalette.actionGreen,
            NumberInboxPalette.actionBlue,
          ]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: FilledButton(
          key: const Key('otp_send_cta'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: ctrl.sending ? null : () => ctrl.sendCode(),
          child: ctrl.sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send code'),
        ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
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
