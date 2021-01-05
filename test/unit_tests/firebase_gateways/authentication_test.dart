import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database_mocks/firebase_database_mocks.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:user_manager/src/entities/user.dart';
import 'package:user_manager/src/exceptions/authentication_exception.dart';
import 'package:user_manager/src/firebase_gateways/firebase_auth_provider.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_repository.dart';
import 'package:user_manager/src/repositories/user_repository.dart';
import 'package:user_manager/src/services/authentication_provider.dart';

import '../mocks/mock_firebase_auth.dart';
import '../mocks/mock_shared_preferences.dart';

class MockFacebookAuth extends Mock implements FacebookAuth {}

void main() {
  FirebaseAuthProvider firebaseAuthProvider;
  UserRepository userRepository;
  firebase_auth.FirebaseAuth mockFirebaseAuth;
  setUp(() async {
    mockFirebaseAuth = MockFirebaseAuth();
    final firebaseFirestore = MockFirestoreInstance();
    final userAdditionalDataCollection = await firebaseFirestore
        .collection(FirebaseUserRepository.usersAdditionalDataReference);
    await userAdditionalDataCollection
        .doc('aabbcc')
        .set(FirebaseUserRepository.initialAdditionalData);

    userRepository = FirebaseUserRepository.forTest(
        firestoreDatabase: firebaseFirestore,
        realTimeDatabase: MockFirebaseDatabase.instance,
        sharedPreferences: MockSharedPreferences());
    firebaseAuthProvider =
        FirebaseAuthProvider.forTest(userRepository, mockFirebaseAuth);
  });
  group('Authentication :', () {
    test('FirebaseUserInterface should be null if no user signed in', () {
      expect(firebaseAuthProvider.user, isNull);
    });

    test('Signin with email and password', () async {
      await firebaseAuthProvider.signInWithEmailAndPassword(
          email: 'test@tes.te', password: 'password');
      await Future.delayed(Duration.zero);
      expect(firebaseAuthProvider.user, isA<User>());
    });

    test('Sign out', () async {
      await firebaseAuthProvider.signInWithEmailAndPassword(
          email: 'test@tes.te', password: 'password');
      await Future.delayed(Duration.zero); // wait for next event loop
      expect(firebaseAuthProvider.user, isA<User>());
      await firebaseAuthProvider.signOut();
      expect(firebaseAuthProvider.user, isNull);
    });

    test(
        'FirebaseAuthProvider should notify its listeners when AuthState changes',
        () async {
      var authStateLog = <AuthState>[];
      firebaseAuthProvider.addListener(() {
        authStateLog.add(firebaseAuthProvider.authState);
      });
      await firebaseAuthProvider.signInWithEmailAndPassword(
        email: 'te@tes.t',
        password: 'password',
      );
      await Future.delayed(Duration.zero); // wait for next event loop
      expect(authStateLog, [
        AuthState.authenticating,
        AuthState.authenticated,
      ]);
      await firebaseAuthProvider.signOut();
      await Future.delayed(Duration.zero); // wait for next event loop
      expect(authStateLog, [
        AuthState.authenticating,
        AuthState.authenticated,
        AuthState.unauthenticated,
      ]);
    });

    test('Register user', () async {
      await firebaseAuthProvider.registerUser(
        firstName: 'firstName',
        lastName: 'lastName',
        email: 'etst@tes.dgg',
        password: 'null',
      );
      await Future.delayed(Duration.zero);
      expect(firebaseAuthProvider.user, isA<User>());
    });

    test('FirebaseAuthProvider should notify its listeners while registration',
        () async {
      var authStateLog = <AuthState>[];
      firebaseAuthProvider.addListener(() {
        authStateLog.add(firebaseAuthProvider.authState);
      });
      await firebaseAuthProvider.registerUser(
        firstName: 'firstName',
        lastName: 'lastName',
        email: 'etst@tes.dgg',
        password: 'null',
      );
      await Future.delayed(Duration.zero); // wait for next event loop
      expect(authStateLog, [AuthState.registering, AuthState.authenticated]);
    });

    test(
        'Once registered user profile should be updated with first and last name',
        () async {
      const firstName = 'Updated', lastName = 'Profile';
      await firebaseAuthProvider.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: 'etst@tes.dgg',
        password: 'null',
      );
      await Future.delayed(Duration.zero); // wait for next event loop
      expect(
          firebaseAuthProvider.user.userName, equals('$firstName $lastName'));
    });
    // TODO test Facebook sign in sign out.
    // test('Sign in with facebook login', () {
    //
    //
    // });
    // TODO : test password reset
  });
  group('Should convert [FirebaseAuthException] with error code', () {
    final methodsToTest = {
      'signInWithEmailAndPassword': () async =>
          await firebaseAuthProvider.signInWithEmailAndPassword(
            email: 'e',
            password: 'p',
          ),
      'registerUser': () async => await firebaseAuthProvider.registerUser(
            firstName: 'firstName',
            lastName: 'lastName',
            email: 'etst@tes.dgg',
            password: 'null',
          ),
    };
    setUp(() {
      MockFirebaseAuth.isExceptionTest =
          true; // if true any method call on [MockFirebaseAuth] will throw a exception.
    });
    tearDownAll(() {
      MockFirebaseAuth.isExceptionTest = false;
    });
    methodsToTest.forEach((methodName, method) {
      final errorCodeMatcher = errorCodeMatcherForEachMethod[methodName];
      errorCodeMatcher.keys.forEach((errorCode) {
        test(
            '[$errorCode] to [AuthenticationException] with ExceptionType [${errorCodeMatcher[errorCode]}].',
            () {
          MockFirebaseAuth.errorCode =
              errorCode; // set error code which will be used to throw the next [FirebaseAuthException].
          expect(
            method,
            throwsA(
              isA<AuthenticationException>().having(
                (e) => e.exceptionType,
                'Exception type',
                equals(errorCodeMatcher[errorCode]),
              ),
            ),
          );
        });
      });
    });
  });
}

final errorCodeMatcherForEachMethod =
    <String, Map<String, AuthenticationExceptionType>>{
  'signInWithEmailAndPassword': {
    'user-not-found': AuthenticationExceptionType.userNotFound,
    'invalid-email': AuthenticationExceptionType.invalidEmail,
    'wrong-password': AuthenticationExceptionType.wrongPassword,
    'user-disabled': AuthenticationExceptionType.userDisabled,
    'too-many-requests': AuthenticationExceptionType.tooManyRequests,
  },
  'registerUser': {
    'invalid-email': AuthenticationExceptionType.invalidEmail,
    'email-already-in-use': AuthenticationExceptionType.emailAlreadyUsed,
    'weak-password': AuthenticationExceptionType.weakPassword,
  },
  // 'signInWithFacebook': {
  //   'invalid-verification-code':
  //       AuthenticationExceptionType.invalidVerificationCode,
  //   'account-exists-with-different-credential':
  //       AuthenticationExceptionType.accountExistsWithDifferentCredential,
  //   'invalid-credential': AuthenticationExceptionType.invalidCredential,
  // }
};
