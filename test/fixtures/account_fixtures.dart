import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:model/account/authentication_type.dart';
import 'package:model/account/personal_account.dart';

class AccountFixtures {
  static final aliceAccountId = AccountId(Id('29883977c13473ae7cb7678ef767cbfbaffc8a44a6e463d971d23a65c1dc4af6'));
  static final bobAccountId = AccountId(Id('6b7d1f2a3c4d5e6f70819263748596a7b8c9d0e1f2a3b4c5d6e7f8091a2b3c4d'));
  static final aliceAccount = PersonalAccount(
    'dab',
    AuthenticationType.oidc,
    isSelected: true,
    accountId: aliceAccountId,
    apiUrl: 'https://domain.com/jmap',
    userName: UserName('Alice')
  );
}