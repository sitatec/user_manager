import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:pedantic/pedantic.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../exceptions/user_data_access_exception.dart';
import '../exceptions/authentication_exception.dart';
import '../services/authentication_provider.dart';
import 'firebase_user_repository.dart';
import '../repositories/user_repository.dart';
import '../entities/user.dart';
import 'firebase_user_transformer.dart';

class FirebaseAuthProvider
    with ChangeNotifier
    implements AuthenticationProvider {
  firebase_auth.FirebaseAuth _firebaseAuth;
  AuthState _state = AuthState.uninitialized;
  final _authStateStreamController = StreamController<AuthState>();
  final UserRepository _userRepository;
  String _authStateSwitchingError;
  User _user;

  static final _singleton = FirebaseAuthProvider._internal();

  factory FirebaseAuthProvider() => _singleton;

  FirebaseAuthProvider._internal()
      : _userRepository = UserRepository.instance,
        _firebaseAuth = firebase_auth.FirebaseAuth.instance {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  @visibleForTesting
  FirebaseAuthProvider.forTest(this._userRepository, this._firebaseAuth)
      : assert(_userRepository != null && _firebaseAuth != null) {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  @override
  AuthState get authState => _state;
  @override
  User get user => _user;
  @override
  String get authStateSwitchingError => _authStateSwitchingError;
  @override
  Stream<AuthState> get authBinaryState => _authStateStreamController.stream;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onAuthStateChanged(firebase_auth.User firebaseUser) async {
    // TODO: refactoring
    _authStateSwitchingError = null;
    try {
      if (firebaseUser == null) {
        _user = null;
        _switchState(AuthState.unauthenticated);
      } else {
        Map<String, dynamic> additionalData;
        if (_state == AuthState.registering) {
          // fetch user profile data that was updated while registering.
          await firebaseUser.reload();
          firebaseUser = _firebaseAuth.currentUser;
          additionalData = FirebaseUserRepository.initialAdditionalData;
          unawaited(_userRepository.initAdditionalData(firebaseUser.uid));
        }
        additionalData =
            await _userRepository.getAdditionalData(firebaseUser.uid);
        _user = FirebaseUserTransformer(
          firebaseUser: firebaseUser,
          additionalData: additionalData,
        );
        _switchState(AuthState.authenticated);
      }
    } catch (e) {
      // TODO implement better error handler.
      _authStateSwitchingError =
          'Une Erreur est survenue lors de la connexion. Veuillez réessayer.';
      notifyListeners();
    }
  }

  @override
  Future<void> signInWithFacebook() async {
    try {
      // ignore: todo
      // TODO test signInWithFacebook
      _switchState(AuthState.authenticating);
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
  Future<void> signInWithEmailAndPassword({
    @required String email,
    @required String password,
  }) async {
    _switchState(AuthState.authenticating);
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
  }) async {
    _switchState(AuthState.registering);
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
      //TODO: tests sendPasswordResetEmail.
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // if (FacebookAuth.instance.isLogged != null) {
      // TODO: test Facebook logout.
      //   await FacebookAuth.instance.logOut();
      // }
      await _firebaseAuth.signOut();
    } catch (e) {
      throw _convertException(e);
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
