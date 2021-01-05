import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:user_manager/src/repositories/user_repository.dart';
import '../entities/user.dart';

import 'firebase_user_repository.dart';

class FirebaseUserInterface implements User {
  final fb.User firebaseUser;
  String _trophies;
  String _rideCount;
  UserRepository _userRepository;
  String _formatedName;
  FirebaseUserInterface({
    @required this.firebaseUser,
    @required userRepository,
  }) {
    _userRepository = userRepository;
    refreshAdditionalData();
    _formatedName = _getFormatedName();
  }

  @override
  String get email => firebaseUser.email;
  @override
  String get phoneNumber => firebaseUser.phoneNumber;
  @override
  String get photoUrl => firebaseUser.photoURL;
  @override
  String get rideCount => _rideCount;
  @override
  String get trophies => _trophies;
  @override
  String get uid => firebaseUser.uid;
  @override
  String get userName => firebaseUser.displayName;
  @override
  String get formatedName => _formatedName;

  String _getFormatedName() {
    final names = userName.split(' ');
    final firstNameCapitalized =
        '${names[0][0].toUpperCase()}${names[0].substring(1)}';
    if (names.length >= 3) return '$firstNameCapitalized ${names[1]}';
    return firstNameCapitalized;
  }

  @override
  Future<void> refreshAdditionalData() async {
    final errorData = {
      FirebaseUserRepository.totalRideCountKey: 'Erreur',
      FirebaseUserRepository.trophiesKey: 'Erreur'
    };
    var additionalData = await _userRepository
        .getAdditionalData(uid)
        ?.catchError((e) => errorData);
    additionalData ??= errorData;
    _trophies = additionalData[FirebaseUserRepository.trophiesKey];
    _rideCount =
        additionalData[FirebaseUserRepository.totalRideCountKey].toString();
  }
}
