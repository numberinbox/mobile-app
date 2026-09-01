import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';

class TwakeWelcomeBindings extends Bindings {
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18080',
  );

  @override
  void dependencies() {
    Get.lazyPut(() => NumberInboxAuthClient(
      Dio(BaseOptions(baseUrl: _apiBaseUrl)),
    ));
    Get.lazyPut(() => TwakeWelcomeController(
      authClient: Get.find<NumberInboxAuthClient>(),
    ));
  }
}
