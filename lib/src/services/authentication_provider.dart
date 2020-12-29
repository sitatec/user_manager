import 'package:flutter/foundation.dart';

import '../firebase_gateways/user.dart';

/// {@template auth_provider}
/// An authentication APIs provider (Sign in, Sign out, register, reset password...)
/// {@endtemplate}
abstract class AuthenticationProvider extends ChangeNotifier {
  AuthStatus get authStatus;
  User get user;

  /// Attempts to sign in a user with the given email address and password.
  ///
  /// If successful, it also signs the user in into the app and [authStatus]
  /// and [user] will be updated and all [AuthenticationProvider] listeners
  /// will be notified (by the [AuthenticationProvider] it self).
  ///
  /// A [AuthenticationException] maybe thrown with the following
  /// exception types:
  /// - `AuthenticationExceptionType.invalidEmail`:
  ///  - Thrown if the email address is not valid.
  /// - `AuthenticationExceptionType.userDisabled`:
  ///  - Thrown if the user corresponding to the given email has been disabled.
  /// - `AuthenticationExceptionType.userNotFound`:
  ///  - Thrown if there is no user corresponding to the given email.
  /// - `AuthenticationExceptionType.wrongPassword`:
  ///  - Thrown if the password is invalid for the given email, or the account
  ///    corresponding to the email does not have a password set.
  /// - `AuthenticationExceptionType.unknown`
  ///  - Thrown if an unidentified error occurred such as server side error
  ///    or Dart exception.
  Future<void> signInWithEmailAndPassword(String email, String password);

  /// Tries to create a new user account with the given email address and
  /// password.
  ///
  /// A [AuthenticationException] maybe thrown with the following
  /// exception types:
  /// - `AuthenticationExceptionType.emailAlreadyUsed`:
  ///  - Thrown if there already exists an account with the given email address.
  /// - `AuthenticationExceptionType.invalidEmail`:
  ///  - Thrown if the email address is not valid.
  /// - `AuthenticationException.userNotFound`:
  ///  - Thrown if the password is not strong enough.
  Future<void> registerUser({
    @required String firstName,
    @required String lastName,
    @required String email,
    @required String password,
    String phoneNumber,
  });

  /// Triggers the Authentication backend (in the current case the Firebase
  /// Authentication backend) to send a password-reset
  /// email to the given email address, which must correspond to an existing
  /// user of your app.
  Future<void> sendPasswordResetEmail(String email);

  /// Signs out the current user.
  ///
  /// If successful, [user] and [authStatus] will be updated and all
  /// [AuthenticationProvider] listeners will be notified.
  Future<void> signOut();
}

enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  registering
}
