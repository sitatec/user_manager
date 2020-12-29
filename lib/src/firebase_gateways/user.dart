import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../entities/user_interface.dart';

class User implements UserInterface {
  final fb.User firebaseUser;
  String _trophies;
  int _rideCount;
  String _initials;

  User.fromFirebaseUser({
    @required this.firebaseUser,
    @required Map<String, String> additionalData,
  }) {
    _trophies = additionalData['trophies'];
    _rideCount = int.tryParse(additionalData['ride_count']) ?? 0;
    if (firebaseUser.photoURL.isEmpty) _getUserNameInitials();
  }

  @override
  String get email => firebaseUser.email;
  @override
  String get initials => _initials;
  @override
  String get phoneNumber => firebaseUser.phoneNumber;
  @override
  String get photoUrl => firebaseUser.photoURL;
  @override
  int get rideCount => _rideCount;
  @override
  String get trophies => _trophies;
  @override
  String get uid => firebaseUser.uid;
  @override
  String get userName => firebaseUser.displayName;

  void _getUserNameInitials() {
    final splitedName = userName.split(' ');
    if (splitedName.first.isNotEmpty) {
      _initials = '${splitedName[0][0]}${splitedName[1][0]}'.toUpperCase();
    } else {
      _initials = userName[0].toUpperCase();
    }
  }
}