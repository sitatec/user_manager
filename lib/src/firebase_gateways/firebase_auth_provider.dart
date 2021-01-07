import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../exceptions/user_data_access_exception.dart';
import '../exceptions/authentication_exception.dart';
import '../services/authentication_provider.dart';
import '../repositories/user_repository.dart';
import '../entities/user.dart';
import 'firebase_user_interface.dart';

class FirebaseAuthProvider
    with ChangeNotifier
    implements AuthenticationProvider {
  firebase_auth.FirebaseAuth _firebaseAuth;
  AuthState _state = AuthState.uninitialized;
  final _authStateStreamController = StreamController<AuthState>.broadcast();
  final UserRepository _userRepository;
  User _user;
  static final _singleton = FirebaseAuthProvider._internal();

  factory FirebaseAuthProvider() => _singleton;

  FirebaseAuthProvider._internal()
      : _userRepository = UserRepository.instance,
        _firebaseAuth = firebase_auth.FirebaseAuth.instance {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    _authStateStreamController.onListen =
        () => _authStateStreamController.sink.add(_state);
  }

  @visibleForTesting
  FirebaseAuthProvider.forTest(this._userRepository, this._firebaseAuth)
      : assert(_userRepository != null && _firebaseAuth != null) {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
    _authStateStreamController.onListen =
        () => _authStateStreamController.sink.add(_state);
  }

  @override
  AuthState get authState => _state;
  @override
  User get user => _user;
  @override
  Stream<AuthState> get authBinaryState => _authStateStreamController.stream;

  @override
  void dispose() {
    _authStateStreamController.close();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(firebase_auth.User firebaseUser) async {
    // TODO: refactoring
    try {
      if (firebaseUser == null) {
        _user = null;
        _switchState(AuthState.unauthenticated);
      } else {
        if (authState == AuthState.registering) {
          // fetch user profile data that was updated while registering.
          await firebaseUser.reload();
          firebaseUser = _firebaseAuth.currentUser;
        }
        _user = FirebaseUserInterface(
          firebaseUser: firebaseUser,
          userRepository: _userRepository,
        );
        _switchState(AuthState.authenticated);
      }
    } catch (e) {
      //TODO: rapport error.
      if (_firebaseAuth.currentUser != null &&
          authState != AuthState.authenticated) {
        _switchState(AuthState.authenticated);
      }
    }
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      // TODO test signInWithFacebook
      _switchState(AuthState.authenticating);
      final facebookLoginAccessToken = await FacebookAuth.instance
          .login(loginBehavior: LoginBehavior.DIALOG_ONLY);
      final facebookOAuthCredential =
          firebase_auth.FacebookAuthProvider.credential(
              facebookLoginAccessToken.token);
      final userCredential =
          await _firebaseAuth.signInWithCredential(facebookOAuthCredential);
      if (userCredential.additionalUserInfo.isNewUser) {
        await _userRepository.initAdditionalData(userCredential.user.uid);
      }
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<void> signInWithEmailAndPassword({
    @required String email,
    @required String password,
  }) async {
    try {
      _switchState(AuthState.authenticating);
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<void> registerUser({
    @required String firstName,
    @required String lastName,
    @required String email,
    @required String password,
  }) async {
    try {
      _switchState(AuthState.registering);
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _userRepository.initAdditionalData(userCredential.user.uid);
      await userCredential.user
          .updateProfile(displayName: '$firstName $lastName');
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      //TODO: tests sendPasswordResetEmail.
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw _handleException(e);
    }
  }

  void _switchState(AuthState targetState) {
    _state = targetState;
    if (targetState == AuthState.authenticated ||
        targetState == AuthState.unauthenticated) {
      _authStateStreamController.sink.add(targetState);
    }
    notifyListeners();
  }

  dynamic _handleException(dynamic exception) {
    if (_firebaseAuth.currentUser == null) {
      _switchState(AuthState.unauthenticated);
    }
    if (exception is firebase_auth.FirebaseAuthException) {
      return _convertFirebaseAuthException(exception);
    }
    if (exception is UserDataAccessException) {
      return exception; // <==> rethrow
    }
    if (exception is FacebookAuthException) {
      return const AuthenticationException.facebookLoginFailed();
    }
    // TODO: implement error rapport systéme.
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
      case 'too-many-requests':
        return const AuthenticationException.tooManyRequests();
        break;
      default:
        return AuthenticationException.unknown();
    }
  }
}
