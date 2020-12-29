import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:pedantic/pedantic.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:user_manager/src/exceptions/user_data_access_exception.dart';
import '../exceptions/authentication_exception.dart';
import '../services/authentication_provider.dart';
import 'user.dart';
import '../repositories/user_repository_interface.dart';
import '../entities/user_interface.dart';
import 'user_repository.dart';

class FirebaseAuthProvider extends ChangeNotifier
    implements AuthenticationProvider {
  firebase_auth.FirebaseAuth _firebaseAuth;
  AuthStatus _status = AuthStatus.uninitialized;
  final UserRepositoryInterface _userRepository;
  UserInterface _user;

  @override
  AuthStatus get authStatus => _status;
  @override
  User get user => _user;

  FirebaseAuthProvider(this._userRepository,
      {firebase_auth.FirebaseAuth firebaseAuth})
      : assert(_userRepository != null) {
    _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(firebase_auth.User firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _switchStatus(AuthStatus.unauthenticated);
    } else {
      Map<String, dynamic> additionalData;
      if (_status == AuthStatus.registering) {
        additionalData = UserRepository.initialAdditionalData;
        unawaited(_userRepository.initAdditionalData(firebaseUser.uid));
      } else {
        additionalData =
            await _userRepository.getAdditionalData(firebaseUser.uid);
      }
      _user = User.fromFirebaseUser(
          firebaseUser: firebaseUser, additionalData: additionalData);
      _switchStatus(AuthStatus.authenticated);
    }
  }

  Future<void> signInWithFacebook() async {
    try {
      _switchStatus(AuthStatus.authenticating);
      final facebookLoginAccessToken = await FacebookAuth.instance.login();
      final facebookAuthCredential =
          firebase_auth.FacebookAuthProvider.credential(
              facebookLoginAccessToken.token);
      await _firebaseAuth.signInWithCredential(facebookAuthCredential);
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _switchStatus(AuthStatus.authenticating);
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> registerUser({
    @required String firstName,
    @required String lastName,
    @required String email,
    @required String password,
    String phoneNumber,
  }) async {
    _switchStatus(AuthStatus.registering);
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      unawaited(_userRepository.initAdditionalData(userCredential.user.uid));
      await userCredential.user
          .updateProfile(displayName: '$firstName $lastName');
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await Future.delayed(Duration.zero);
    } catch (e) {
      throw _convertException(e);
    }
  }

  void _switchStatus(AuthStatus targetStatus) {
    _status = targetStatus;
    notifyListeners();
  }

  dynamic _convertException(dynamic exception) {
    if (exception is firebase_auth.FirebaseAuthException) {
      return _convertFirebaseAuthException(exception);
    }
    if (exception is UserDataAccessException) {
      return exception; // <==> rethrow
    }
    return const AuthenticationException.unknown();
  }

  AuthenticationException _convertFirebaseAuthException(
      firebase_auth.FirebaseAuthException exception) {
    switch (exception.code) {
      case 'account-exists-with-different-credential':
        return const AuthenticationException
            .accountExistsWithDifferentCredential();
        break;
      case 'invalid-credential':
        return const AuthenticationException.invalidCredential();
        break;
      case 'invalid-verification-code':
        return const AuthenticationException.invalidVerificationCode();
        break;
      case 'email-already-in-use':
        return const AuthenticationException.emailAlreadyUsed();
        break;
      case 'weak-password':
        return const AuthenticationException.weakPassword();
      case 'invalid-email':
        return const AuthenticationException.invalidEmail();
        break;
      case 'user-disabled':
        return const AuthenticationException.userDisabled();
        break;
      case 'user-not-found':
        return const AuthenticationException.userNotFound();
        break;
      case 'wrong-password':
        return const AuthenticationException.wrongPassword();
        break;
      default:
        return AuthenticationException.unknown();
    }
  }
}
