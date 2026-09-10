import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:tmail_ui_user/features/numberinbox/auth/numberinbox_auth_client.dart';
import 'package:tmail_ui_user/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart';
import 'package:tmail_ui_user/main/utils/app_config.dart';

class TwakeWelcomeBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NumberInboxAuthClient(
      Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
    ));
    Get.lazyPut(() => TwakeWelcomeController(
      authClient: Get.find<NumberInboxAuthClient>(),
    ));
  }
}
