import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem.dart';
import 'package:tmail_ui_user/features/mailbox_dashboard/domain/linagora_ecosystem/linagora_ecosystem_handler.dart';

part 'linagora_ecosystem_handler_registry.g.dart';

class LinagoraEcosystemHandlerRegistry {
  /// Provider-scoped [Ref], safe to read from another widget's `dispose()`
  /// unlike a [WidgetRef] captured from a widget that may unmount.
  final Ref ref;

  final List<LinagoraEcosystemHandler> _handlers = [];

  /// Bumped by every dispatch so a deferred clear can detect that a newer
  /// dispatch already superseded it.
  int _dispatchEpoch = 0;

  LinagoraEcosystemHandlerRegistry(this.ref);

  bool get hasHandlers => _handlers.isNotEmpty;

  void register(LinagoraEcosystemHandler handler) => _handlers.add(handler);

  void dispatchLoaded(LinagoraEcosystem ecosystem) {
    _dispatchEpoch++;
    for (final handler in _handlers) {
      handler.onEcosystemLoaded(ecosystem);
    }
  }

  void dispatchCleared() {
    _dispatchEpoch++;
    for (final handler in _handlers) {
      handler.onEcosystemCleared();
    }
  }

  /// Same as [dispatchCleared], but defers the handler calls to a microtask.
  ///
  /// Widgets unmounting during the tree's finalization phase (their
  /// `dispose()`) must not mutate Riverpod providers synchronously — doing so
  /// asserts in debug builds ("Tried to modify a provider while the widget
  /// tree was building"). The deferred clear runs once the current frame
  /// finishes, and is skipped entirely if any other dispatch (e.g. a freshly
  /// mounted dashboard loading its ecosystem in the same frame) happened
  /// first.
  ///
  void scheduleDispatchCleared() {
    final epoch = _dispatchEpoch;
    scheduleMicrotask(() {
      if (_dispatchEpoch != epoch) return;
      dispatchCleared();
    });
  }

  void dispatchAccountChanged() {
    _dispatchEpoch++;
    for (final handler in _handlers) {
      handler.onEcosystemCleared();
      if (handler is AccountAwareLinagoraEcosystemHandler) {
        (handler as AccountAwareLinagoraEcosystemHandler).onAccountChanged();
      }
    }
  }
}

/// App-lifetime registry: handlers are registered once and must survive the
/// dashboard being rebuilt.
@Riverpod(keepAlive: true)
LinagoraEcosystemHandlerRegistry linagoraEcosystemHandlerRegistry(Ref ref) =>
    LinagoraEcosystemHandlerRegistry(ref);
