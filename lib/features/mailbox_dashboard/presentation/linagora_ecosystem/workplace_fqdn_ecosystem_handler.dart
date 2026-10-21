import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem_handler.dart';
import 'package:tmail_ui_user/features/paywall/domain/model/paywall_url_pattern.dart';
import 'package:tmail_ui_user/main/providers/workplace/fqdn/workplace_fqdn_ecosystem_notifier.dart';

typedef ResolveOwnerEmail = String? Function();

/// Feeds the ecosystem FQDN template into the ecosystem FQDN source so
/// deployments without an OIDC `workplaceFqdn` claim still reach their
/// Workplace.
///
/// Takes the registry's own provider-scoped [Ref] (see
/// `LinagoraEcosystemHandlerRegistry.ref`), not a [WidgetRef] — the registry
/// is app-lifetime and dispatches `onEcosystemCleared` from another widget's
/// `dispose()`, where a captured [WidgetRef] would already be unsafe to use.
class WorkplaceFqdnEcosystemHandler implements LinagoraEcosystemHandler {
  final Ref _ref;
  final ResolveOwnerEmail _resolveOwnerEmail;

  /// Set when the provider container that owns [_ref] is torn down.
  ///
  /// The ecosystem clear is deferred out of the widget dispose phase (a
  /// provider must not be mutated while the widget tree is finalizing), so
  /// it can land after the container went away. Reading through an unmounted
  /// ref throws, and there is nothing left to clear in that case.
  bool _disposed = false;

  WorkplaceFqdnEcosystemHandler({
    required Ref ref,
    required ResolveOwnerEmail resolveOwnerEmail,
  })  : _ref = ref,
        _resolveOwnerEmail = resolveOwnerEmail {
    _ref.onDispose(() => _disposed = true);
  }

  @override
  void onEcosystemLoaded(LinagoraEcosystem ecosystem) {
    _setEcosystemFqdn(_resolveFallbackFqdn(ecosystem));
  }

  @override
  void onEcosystemCleared() => _setEcosystemFqdn(null);

  String? _resolveFallbackFqdn(LinagoraEcosystem ecosystem) {
    final template = ecosystem.workplaceFqdnFallbackTemplate;
    if (template == null) return null;

    final resolved = PaywallUrlPattern(template)
        .resolveQualifiedUrl(ownerEmail: _resolveOwnerEmail()?.trim() ?? '')
        ?.trim();
    return (resolved == null || resolved.isEmpty) ? null : resolved;
  }

  void _setEcosystemFqdn(String? fqdn) {
    if (_disposed) return;
    _ref.read(workplaceFqdnEcosystemProvider.notifier).setFqdn(fqdn);
  }
}
