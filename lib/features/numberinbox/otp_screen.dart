import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/e164.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/numberinbox/numberinbox_otp_controller.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/routes/route_navigation.dart';

class NumberInboxOtpScreen extends StatefulWidget {
  const NumberInboxOtpScreen({
    super.key,
    this.client,
    this.onSession,
  });

  final NumberInboxAuthClient? client;
  final void Function(OtpSession)? onSession;

  @override
  State<NumberInboxOtpScreen> createState() => _NumberInboxOtpScreenState();
}

enum _OtpPhase { phone, code }

class _NumberInboxOtpScreenState extends State<NumberInboxOtpScreen> {
  _OtpPhase _phase = _OtpPhase.phone;
  String? _error;
  Country _selectedCountry = countries.first;
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18080',
  );

  late final NumberInboxAuthClient _client = widget.client ??
      NumberInboxAuthClient(Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      )));

  String get _fullE164 => _selectedCountry.buildE164(_phoneCtrl.text.trim());

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('NumberInbox'), backgroundColor: colors.primary),
      body: Container(
        color: colors.surface,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to NumberInbox',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to receive a verification code.',
              style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            if (_phase == _OtpPhase.phone) ...[
              Row(
                children: [
                  GestureDetector(
                    key: const Key('otp_country_picker'),
                    onTap: _showCountryPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 4),
                          Text(
                            _selectedCountry.dialCode,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('otp_phone_field'),
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: '812 345 678',
                        errorText: _error,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('otp_send_cta'),
                onPressed: _sending ? null : _sendCode,
                child: _sending
                    ? const CircularProgressIndicator()
                    : const Text('Send code'),
              ),
            ] else ...[
              TextField(
                key: const Key('otp_code_field'),
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  hintText: '123456',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('otp_verify_cta'),
                onPressed: _verifying ? null : _verifyCode,
                child: _verifying
                    ? const CircularProgressIndicator()
                    : const Text('Verify'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('otp_error'),
                style: TextStyle(color: colors.error, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CountryPickerSheet(
        selectedCountry: _selectedCountry,
        onSelected: (country) {
          setState(() => _selectedCountry = country);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }
    if (!_selectedCountry.isValidPhone(phone)) {
      setState(() => _error = 'Enter a valid ${_selectedCountry.name} phone number');
      return;
    }

    final e164 = _fullE164;
    try {
      debugPrint('[OTP] Sending code to: $e164, baseUrl=$_baseUrl');
      setState(() {
        _sending = true;
        _error = null;
      });
      await _client.startOtp(e164);
      debugPrint('[OTP] Code sent successfully');
      setState(() {
        _phase = _OtpPhase.code;
        _sending = false;
      });
    } on InvalidE164Exception {
      setState(() => _error = 'Invalid phone number format');
    } on RateLimitedException {
      setState(() => _error = 'Too many attempts. Try again later.');
    } catch (e) {
      setState(() => _error = 'Failed to send code: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final otpSession = await _client.verifyOtp(_fullE164, code);

      if (widget.onSession != null) {
        if (mounted) widget.onSession!(otpSession);
      } else {
        _handleOtpSuccess(otpSession);
      }
    } on OtpInvalidException {
      setState(() => _error = 'Invalid code. Try again.');
    } on RateLimitedException {
      setState(() => _error = 'Too many attempts. Try again later.');
    } catch (e) {
      setState(() => _error = 'Verification failed. Try again.');
    } finally {
      setState(() => _verifying = false);
    }
  }

  void _handleOtpSuccess(OtpSession otpSession) {
    if (Get.isRegistered<NumberInboxOtpController>()) {
      final controller = Get.find<NumberInboxOtpController>();
      controller.onOtpVerified(otpSession);
    } else {
      debugPrint('[OTP] Controller not registered, navigating directly');
      pushAndPopAll(AppRoutes.dashboard);
    }
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
                    trailing: selected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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
