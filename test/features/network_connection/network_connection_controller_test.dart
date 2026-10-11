import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:tmail_ui_user/features/network_connection/presentation/network_connection_controller.dart';

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  final StreamController<ConnectivityResult> _controller =
      StreamController<ConnectivityResult>.broadcast();

  @override
  Future<ConnectivityResult> checkConnectivity() async => ConnectivityResult.wifi;

  @override
  Stream<ConnectivityResult> get onConnectivityChanged => _controller.stream;

  void emit(ConnectivityResult result) => _controller.add(result);
}

class _FakeInternetConnectionChecker implements InternetConnectionChecker {
  _FakeInternetConnectionChecker({required this.initialStatus});

  final InternetConnectionStatus initialStatus;

  /// The real probe is slower than the change stream, which is what lets it
  /// resolve after the stream and report a stale status.
  static const probeDelay = Duration(milliseconds: 120);

  @override
  Duration get checkInterval => const Duration(milliseconds: 5);

  @override
  Duration get checkTimeout => const Duration(milliseconds: 5);

  List<AddressCheckOptions> _addresses = const [];

  final StreamController<InternetConnectionStatus> _controller =
      StreamController<InternetConnectionStatus>.broadcast();

  @override
  List<AddressCheckOptions> get addresses => _addresses;

  @override
  set addresses(List<AddressCheckOptions> value) => _addresses = value;

  @override
  bool get hasListeners => _controller.hasListener;

  @override
  bool get isActivelyChecking => _controller.hasListener;

  @override
  Future<AddressCheckResult> isHostReachable(AddressCheckOptions options) async =>
      AddressCheckResult(options, isSuccess: false);

  @override
  Future<bool> get hasConnection async =>
      initialStatus == InternetConnectionStatus.connected;

  @override
  Future<InternetConnectionStatus> get connectionStatus async {
    await Future<void>.delayed(probeDelay);
    return initialStatus;
  }

  @override
  Stream<InternetConnectionStatus> get onStatusChange => _controller.stream;

  void emit(InternetConnectionStatus status) => _controller.add(status);
}

void main() {
  group('NetworkConnectionController internet status', () {
    late _FakeConnectivityPlatform connectivityPlatform;
    late _FakeInternetConnectionChecker internetChecker;
    late NetworkConnectionController controller;
    late ConnectivityPlatform originalPlatform;

    setUp(() {
      originalPlatform = ConnectivityPlatform.instance;
      connectivityPlatform = _FakeConnectivityPlatform();
      ConnectivityPlatform.instance = connectivityPlatform;

      internetChecker = _FakeInternetConnectionChecker(
        initialStatus: InternetConnectionStatus.disconnected,
      );
      controller = NetworkConnectionController(
        Connectivity(),
        internetConnectionChecker: internetChecker,
      );
    });

    tearDown(() async {
      controller.onClose();
      ConnectivityPlatform.instance = originalPlatform;
      await Future<void>.delayed(Duration.zero);
    });

    test(
      'startup probe keeps the status when the stream already reported connected',
      () async {
        controller.onInit();
        controller.onReady();

        // The stream reports online first, then the slower startup probe
        // resolves with a stale "disconnected" while requests actually succeed.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        internetChecker.emit(InternetConnectionStatus.connected);
        await Future<void>.delayed(const Duration(milliseconds: 250));

        expect(
          controller.isNetworkConnectionAvailable(),
          isTrue,
          reason: 'a stale startup probe must not override a live connected report',
        );
      },
    );

    test(
      'stream reports a genuine disconnect after being connected',
      () async {
        controller.onInit();
        controller.onReady();

        internetChecker.emit(InternetConnectionStatus.connected);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(controller.isNetworkConnectionAvailable(), isTrue);

        internetChecker.emit(InternetConnectionStatus.disconnected);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          controller.isNetworkConnectionAvailable(),
          isFalse,
          reason: 'the change stream must still be able to report a real outage',
        );
      },
    );
  });
}