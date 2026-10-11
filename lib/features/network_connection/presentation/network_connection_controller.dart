import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core/utils/app_logger.dart';
import 'package:core/utils/platform_info.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkConnectionController extends GetxController {
  static const Duration _timeoutInternetConnection = Duration(milliseconds: 5000);
  static const Duration _timeIntervalInternetConnection = Duration(milliseconds: 5000);

  final _connectivityResult = Rxn<ConnectivityResult>();
  final _internetConnectionStatus = Rxn<InternetConnectionStatus>();

  /// Whether the change stream has already reported a status. The startup
  /// probe can resolve after the stream and report a stale `disconnected`
  /// while requests actually succeed, so the probe must not overwrite the
  /// stream once the stream has spoken.
  var _hasInternetStatusFromStream = false;

  final Connectivity _connectivity;

  final InternetConnectionChecker _internetConnectionChecker;

  StreamSubscription<ConnectivityResult>? _subscription;
  StreamSubscription<InternetConnectionStatus>? _internetSubscription;

  NetworkConnectionController(
    this._connectivity, {
    InternetConnectionChecker? internetConnectionChecker,
  }) : _internetConnectionChecker = internetConnectionChecker ??
            InternetConnectionChecker.createInstance(
              checkTimeout: _timeoutInternetConnection,
              checkInterval: _timeIntervalInternetConnection,
            );

  @override
  void onInit() {
    super.onInit();
    _listenNetworkConnectionChanged();
  }

  @override
  void onReady() {
    super.onReady();
    _getCurrentNetworkConnectionState();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    if (PlatformInfo.isMobile) {
      _internetSubscription?.cancel();
    }
    super.onClose();
  }

  Connectivity get connectivity => _connectivity;

  void _getCurrentNetworkConnectionState() async {
    final listConnectionResult = await Future.wait([
      _connectivity.checkConnectivity(),
      _internetConnectionChecker.connectionStatus,
    ]);
    log('NetworkConnectionController::_getCurrentNetworkConnectionState():listConnectionResult: $listConnectionResult');

    if (listConnectionResult[0] is ConnectivityResult) {
      _setNetworkConnectivityState(listConnectionResult[0] as ConnectivityResult);
    }

    if (listConnectionResult[1] is InternetConnectionStatus) {
      _setInternetConnectivityStatus(
        listConnectionResult[1] as InternetConnectionStatus,
        isStartupProbe: true,
      );
    }
  }

  void _listenNetworkConnectionChanged() {
    _subscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        log('NetworkConnectionController::_listenNetworkConnectionChanged()::onConnectivityChanged: $result');
        _setNetworkConnectivityState(result);
      },
      onError: (error, stackTrace) {
        logWarning('NetworkConnectionController::_listenNetworkConnectionChanged()::onConnectivityChanged:error: $error | stackTrace: $stackTrace');
      }
    );

    _internetSubscription = _internetConnectionChecker.onStatusChange.listen(
      (status) {
log('NetworkConnectionController::_listenNetworkConnectionChanged()::onStatusChange: $status');
      _setInternetConnectivityStatusFromStream(status);
      },
      onError: (error, stackTrace) {
        logWarning('NetworkConnectionController::_listenNetworkConnectionChanged()::onStatusChange:error: $error | stackTrace: $stackTrace');
      }
    );
  }

  void _setNetworkConnectivityState(ConnectivityResult newConnectivityResult) {
    _connectivityResult.value = newConnectivityResult;
  }

  void _setInternetConnectivityStatus(
    InternetConnectionStatus newStatus, {
    bool isStartupProbe = false,
  }) {
    if (isStartupProbe && _hasInternetStatusFromStream) {
      log('NetworkConnectionController::_setInternetConnectivityStatus:'
          ' ignoring stale startup probe status: $newStatus');
      return;
    }
    _internetConnectionStatus.value = newStatus;
  }

  void _setInternetConnectivityStatusFromStream(
    InternetConnectionStatus newStatus,
  ) {
    _hasInternetStatusFromStream = true;
    _setInternetConnectivityStatus(newStatus);
  }

  bool isNetworkConnectionAvailable() {
    return _internetConnectionStatus.value == InternetConnectionStatus.connected;
  }

  Future<bool> hasInternetConnection() {
    return _internetConnectionChecker.hasConnection;
  }
}