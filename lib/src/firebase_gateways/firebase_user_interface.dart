import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../repositories/user_repository.dart';
import '../utils/utils.dart';
import '../entities/user.dart';

import 'firebase_user_repository.dart';

// TODO: Refactor (keys and ride count handling).
class FirebaseUserInterface implements User {
  final fb.User firebaseUser;
  String _trophies;
  String _trophiesCount;
  String _rideCount;
  UserRepository _userRepository;
  String _formatedName;
  Map<String, dynamic> _rideCountHistory;
  Map<String, dynamic> _reviews;
  FirebaseUserInterface({
    @required this.firebaseUser,
    @required UserRepository userRepository,
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
  @override
  String get trophiesCount => _trophiesCount;
  @override
  Map<String, dynamic> get rideCountHistory => _rideCountHistory;
  // @override
  // Map<String, dynamic> get reviews => _reviews;

  String _getFormatedName() {
    final names = userName.split(' ');
    final firstNameCapitalized =
        '${names[0][0].toUpperCase()}${names[0].substring(1)}';
    if (names.length >= 3) return '$firstNameCapitalized ${names[1]}';
    return firstNameCapitalized;
  }

  @override
  Future<void> refreshAdditionalData() async {
    // TODO: Refactoring.
    // TODO : Test: Ui most correctly display 'Erreur' (without overflow) when a error occur
    final errorData = {
      FirebaseUserRepository.totalRideCountKey: 'Erreur',
      FirebaseUserRepository.trophiesKey: 'Erreur',
    };
    var additionalData = await _userRepository
        .getAdditionalData(uid)
        ?.catchError((e) => errorData);
    additionalData ??= errorData;
    _trophies = additionalData[FirebaseUserRepository.trophiesKey];
    _rideCount =
        additionalData[FirebaseUserRepository.totalRideCountKey].toString();
    if (_trophies != 'Erreur') {
      _trophiesCount = ((trophies.split('')?.length) ?? 0).toString();
    } else {
      _trophiesCount = 'Erreur';
    }
    _rideCountHistory = _getUserInterfaceFriendlyHistory();
  }

  Map<String, dynamic> _getUserInterfaceFriendlyHistory() {
    final rideCountHistory = _userRepository.getRideCountHistory();
    _replaceWithUserFriendlyKey(
      originalData: rideCountHistory,
      keyMatcher: _getThe3LastDaysUserFriendlyHistoryKey(),
    );
    return rideCountHistory;
  }

  void _replaceWithUserFriendlyKey({
    @required Map<String, dynamic> originalData,
    @required Map<String, String> keyMatcher,
  }) {
    keyMatcher.forEach((originalKey, userFriendlyKey) {
      if (originalData.containsKey(originalKey)) {
        originalData[userFriendlyKey] = originalData[originalKey];
        originalData.remove(originalKey);
      } else {
        originalData[userFriendlyKey] = 0;
      }
    });
  }

  Map<String, String> _getThe3LastDaysUserFriendlyHistoryKey() {
    final now = DateTime.now();
    return {
      generateKeyFromDateTime(now): "Aujourd'hui",
      generateKeyFromDateTime(now.subtract(Duration(days: 1))): 'Hier',
      generateKeyFromDateTime(now.subtract(Duration(days: 2))): 'Avant-hier'
    };
  }
}
