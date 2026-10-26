import 'dart:async';

import 'package:core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/numberinbox/platform_api_options.dart';
import 'package:tmail_ui_user/features/base/base_controller.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/widgets/branded_action_button.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
import 'package:tmail_ui_user/main/utils/twake_app_manager.dart';
import 'package:uuid/uuid.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({
    super.key,
    this.client,
    this.credentialRepository,
    this.onDeleted,
  });

  final AccountDeletionClient? client;
  final CredentialRepository? credentialRepository;
  final Future<void> Function()? onDeleted;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  static const _requestIdSuffix = 'requestId';
  static const _statusTokenSuffix = 'statusToken';
  static const _idempotencyKeySuffix = 'idempotencyKey';

  // Keys written before request state was scoped to an account. Deleting them
  // prevents one account's pending deletion from being resumed by another
  // account signed in on the same device.
  static const _legacyKeys = <String>[
    'numberinbox.accountDeletion.requestId',
    'numberinbox.accountDeletion.statusToken',
    'numberinbox.accountDeletion.idempotencyKey',
  ];

  final _phoneController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  AccountDeletionClient? _client;
  CredentialRepository? _credentials;
  Country _country = defaultCountry();
  Timer? _pollTimer;
  String? _requestId;
  String? _statusToken;
  String? _storageScope;
  String? _error;
  bool _loading = true;

  /// True only while a confirmed deletion request is being sent, so the CTA
  /// spinner means "this is happening" rather than "the page is loading".
  bool _submitting = false;
  bool _pending = false;
  bool _completed = false;

  AccountDeletionClient get client => _client ??= widget.client ??
      AccountDeletionClient(Dio(platformApiOptions(AppConfig.apiBaseUrl)));
  CredentialRepository get credentials => _credentials ??=
      widget.credentialRepository ?? Get.find<CredentialRepository>();

  @override
  void initState() {
    super.initState();
    _restorePendingRequest();
  }

  String _scopedKey(String suffix) =>
      'numberinbox.accountDeletion.$_storageScope.$suffix';

  String _scopeFor(String username) => username.trim().toLowerCase();

  Future<void> _deleteLegacyKeys() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  Future<void> _restorePendingRequest() async {
    try {
      final auth = await credentials.getAuthenticationInfoStored();
      _storageScope = _scopeFor(auth.username);
      await _deleteLegacyKeys();
      final number = auth.username.split('@').first;
      final matching = countries.where((c) => number.startsWith(c.dialCode)).toList()
        ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
      final requestId = await _storage.read(key: _scopedKey(_requestIdSuffix));
      final statusToken =
          await _storage.read(key: _scopedKey(_statusTokenSuffix));
      if (!mounted) return;
      setState(() {
        if (matching.isNotEmpty) _country = matching.first;
        _requestId = requestId;
        _statusToken = statusToken;
        _pending = requestId != null && statusToken != null;
        _loading = false;
      });
      if (_pending) await _checkStatus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your signed-in mailbox could not be verified. Please sign in again.';
      });
    }
  }

  String _enteredNumber() {
    final input = _phoneController.text.trim();
    final number = _country.parseE164(input);
    if (number == null) throw const FormatException('Invalid phone number');
    return number;
  }

  Future<void> _submit() async {
    if (_loading || _pending) return;
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }
    try {
      final auth = await credentials.getAuthenticationInfoStored();
      final confirmed = _enteredNumber();
      if (auth.username.split('@').first != confirmed) {
        setState(() => _error = 'This number does not match your signed-in mailbox.');
        return;
      }
      if (!mounted) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete your NumberInbox account?'),
          content: const Text(
            'Your mailbox and its messages will be deleted. This cannot be undone. '
            'Mail sent to your number later may create a new, empty mailbox.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              // Red is reserved for this one action: it is the only
              // irreversible thing in the flow.
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      setState(() {
        _loading = true;
        _submitting = true;
        _error = null;
      });
      _storageScope = _scopeFor(auth.username);
      final key = await _storage.read(key: _scopedKey(_idempotencyKeySuffix)) ??
          const Uuid().v4();
      await _storage.write(key: _scopedKey(_idempotencyKeySuffix), value: key);
      final result = await client.request(
        confirmE164: confirmed,
        username: auth.username,
        password: auth.password,
        idempotencyKey: key,
      );
      await _storage.write(
          key: _scopedKey(_requestIdSuffix), value: result.requestId);
      await _storage.write(
          key: _scopedKey(_statusTokenSuffix), value: result.statusToken);
      if (!mounted) return;
      setState(() {
        _requestId = result.requestId;
        _statusToken = result.statusToken;
        _pending = true;
        _loading = false;
      });
      await _checkStatus();
    } on ArgumentError {
      if (mounted) setState(() => _error = 'Enter a valid phone number.');
    } on AccountDeletionException catch (error) {
      if (mounted) {
        setState(() => _error = switch (error.code) {
          'number_mismatch' => 'This number does not match your signed-in mailbox.',
          'unauthorized' => 'Your mailbox session has expired. Please sign in again.',
          'deletion_in_progress' => 'Deletion is already in progress. Please try again shortly.',
          _ => 'Could not start deletion. Please try again.',
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start deletion. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _submitting = false;
        });
      }
    }
  }

  Future<void> _checkStatus() async {
    _pollTimer?.cancel();
    final requestId = _requestId;
    final token = _statusToken;
    if (requestId == null || token == null || !mounted) return;
    try {
      final status = await client.status(requestId, token);
      if (!mounted) return;
      if (status == 'completed') {
        await _finish();
      } else if (status == 'failed') {
        setState(() => _error =
            'Deletion could not finish. Please contact NumberInbox support.');
      } else {
        setState(() => _error = null);
        _pollTimer = Timer(const Duration(seconds: 2), _checkStatus);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check deletion progress. Try again.');
      }
    }
  }

  Future<void> _finish() async {
    if (_completed) return;
    _completed = true;
    _pollTimer?.cancel();
    if (_storageScope != null) {
      await _storage.delete(key: _scopedKey(_requestIdSuffix));
      await _storage.delete(key: _scopedKey(_statusTokenSuffix));
      await _storage.delete(key: _scopedKey(_idempotencyKeySuffix));
    }
    if (widget.onDeleted != null) {
      await widget.onDeleted!();
      return;
    }
    if (Get.isRegistered<ManageAccountDashBoardController>()) {
      final dashboard = Get.find<ManageAccountDashBoardController>();
      await dashboard.clearAllData();
      if (!mounted) return;
      dashboard.navigateToTwakeWelcomePage(popAllRoute: true);
      return;
    }
    // Completed deletion must never silently stop: even when the dashboard
    // controller is already gone, clear local session data and show login.
    logWarning('AccountDeletionPage::_finish: dashboard controller not '
        'registered; clearing session data directly');
    await Get.find<TwakeAppManager>().runClearDataOnce(clearLocalSessionData);
    if (!mounted) return;
    if (Get.currentRoute != AppRoutes.twakeWelcome) {
      Get.offAllNamed(AppRoutes.twakeWelcome);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Delete your NumberInbox account',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your mailbox and messages will be permanently removed. '
              'Enter the phone number linked to this mailbox to continue. '
              'No additional SMS code is needed while you are signed in.',
            ),
            const SizedBox(height: 24),
            if (!_pending) ...[
              Row(children: [
                DropdownButton<Country>(
                  value: _country,
                  items: countries.map((country) => DropdownMenuItem(
                    value: country,
                    child: Text('${country.flag} ${country.dialCode}'),
                  )).toList(),
                  onChanged: _loading ? null : (country) {
                    if (country != null) setState(() => _country = country);
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('deletion_phone_field'),
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              BrandedActionButton(
                buttonKey: const Key('deletion_submit'),
                label: 'Continue',
                // Disabled while the page restores, spinner only while a
                // confirmed request is on its way.
                isEnabled: !_loading,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ] else ...[
              const Text('Deleting your mailbox and account data…'),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _checkStatus,
                child: const Text('Check progress'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
