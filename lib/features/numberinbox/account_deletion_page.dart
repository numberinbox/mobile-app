import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/login/domain/repository/credential_repository.dart';
import 'package:tmail_ui_user/features/manage_account/presentation/manage_account_dashboard_controller.dart';
import 'package:tmail_ui_user/features/numberinbox/account_deletion_client.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/e164.dart';
import 'package:tmail_ui_user/features/numberinbox/country.dart';
import 'package:tmail_ui_user/main/routes/app_routes.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';
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
  static const _requestIdKey = 'numberinbox.accountDeletion.requestId';
  static const _statusTokenKey = 'numberinbox.accountDeletion.statusToken';
  static const _idempotencyKey = 'numberinbox.accountDeletion.idempotencyKey';

  final _phoneController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  AccountDeletionClient? _client;
  CredentialRepository? _credentials;
  Country _country = defaultCountry();
  Timer? _pollTimer;
  String? _requestId;
  String? _statusToken;
  String? _error;
  bool _loading = true;
  bool _pending = false;
  bool _completed = false;

  AccountDeletionClient get client => _client ??= widget.client ??
      AccountDeletionClient(Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)));
  CredentialRepository get credentials => _credentials ??=
      widget.credentialRepository ?? Get.find<CredentialRepository>();

  @override
  void initState() {
    super.initState();
    _restorePendingRequest();
  }

  Future<void> _restorePendingRequest() async {
    try {
      final auth = await credentials.getAuthenticationInfoStored();
      final number = auth.username.split('@').first;
      final matching = countries.where((c) => number.startsWith(c.dialCode)).toList()
        ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
      final requestId = await _storage.read(key: _requestIdKey);
      final statusToken = await _storage.read(key: _statusTokenKey);
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
    return normalizeE164(input.startsWith('+') ? input : _country.buildE164(input));
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      setState(() {
        _loading = true;
        _error = null;
      });
      final key = await _storage.read(key: _idempotencyKey) ?? const Uuid().v4();
      await _storage.write(key: _idempotencyKey, value: key);
      final result = await client.request(
        confirmE164: confirmed,
        username: auth.username,
        password: auth.password,
        idempotencyKey: key,
      );
      await _storage.write(key: _requestIdKey, value: result.requestId);
      await _storage.write(key: _statusTokenKey, value: result.statusToken);
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
      if (mounted) setState(() => _loading = false);
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
    await _storage.delete(key: _requestIdKey);
    await _storage.delete(key: _statusTokenKey);
    await _storage.delete(key: _idempotencyKey);
    if (widget.onDeleted != null) {
      await widget.onDeleted!();
    } else {
      await Get.find<ManageAccountDashBoardController>().clearAllData();
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
              FilledButton(
                key: const Key('deletion_submit'),
                onPressed: _loading ? null : _submit,
                child: const Text('Delete account'),
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
