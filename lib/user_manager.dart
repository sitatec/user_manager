library user_manager;

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'src/services/authentication_provider.dart';
export 'src/repositories/user_repository.dart';
export 'src/entities/user.dart';
export 'src/exceptions/authentication_exception.dart';
export 'src/exceptions/user_data_access_exception.dart';

/// Initialize all [user_manager] services and dependencies.
Future<FirebaseApp> initializeBackEndServices() async {
  // await SharedPreferences.setMockInitialValues({});
  return Firebase.initializeApp();
}
