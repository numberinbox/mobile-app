import 'package:fcm/model/firebase_registration.dart';
import 'package:fcm/model/type_name.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/state.dart' as jmap;
import 'package:jmap_dart_client/jmap/core/user_name.dart';

abstract class FCMDatasource {
  Future<void> storeStateToRefresh(AccountId accountId, UserName userName, TypeName typeName, jmap.State newState);

  Future<jmap.State> getStateToRefresh(AccountId accountId, UserName userName, TypeName typeName);

  Future<void> deleteStateToRefresh(AccountId accountId, UserName userName, TypeName typeName);

  Future<void> storeFirebaseRegistration(FirebaseRegistration firebaseRegistration);

  Future<FirebaseRegistration> getStoredFirebaseRegistration();

  Future<void> deleteFirebaseRegistrationCache();
}
