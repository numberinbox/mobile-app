import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tmail_ui_user/features/composer/data/datasource_impl/contact_datasource_impl.dart';
import 'package:tmail_ui_user/main/exceptions/thrower/exception_thrower.dart';

class _RethrowingThrower implements ExceptionThrower {
  @override
  throwException(error, stackTrace) => throw error;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('github.com/clovisnicolas/flutter_contacts');

  late ContactDataSourceImpl dataSource;

  setUp(() {
    dataSource = ContactDataSourceImpl(_RethrowingThrower());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getContacts') {
        return [
          {
            'displayName': 'Alice',
            'emails': [
              {'label': 'home', 'value': 'alice@example.com'},
            ],
            'phones': [],
          },
          {
            'displayName': 'Bob',
            'emails': [],
            'phones': [
              {'label': 'mobile', 'value': '+66812345678'},
            ],
          },
          {
            'displayName': 'NoDetails',
            'emails': [],
            'phones': [],
          },
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ContactDataSourceImpl::getAllContacts', () {
    test('maps email and phone contacts, skips empty ones', () async {
      final result = await dataSource.getAllContacts();

      expect(result, hasLength(2));
      expect(result[0].displayName, 'Alice');
      expect(result[0].email, 'alice@example.com');
      expect(result[1].displayName, 'Bob');
      expect(result[1].email, '+66812345678@numberinbox.com');
    });

    test('propagates channel errors via the thrower', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'PERMISSION_DENIED');
      });

      expect(() => dataSource.getAllContacts(), throwsA(isA<PlatformException>()));
    });
  });
}
