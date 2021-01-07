import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';
import '../exceptions/user_data_access_exception.dart';
import '../repositories/user_repository.dart';

class FirebaseUserRepository implements UserRepository {
  SharedPreferences _sharedPreferences;
  CollectionReference _additionalDataReference;
  final FirebaseFirestore _firebaseFirestore;
  final DatabaseReference _realTimeDatabaseReference;
  static const trophiesKey = 't';
  static const totalRideCountKey = 'r';
  static const initialAdditionalData = {
    trophiesKey: '',
    totalRideCountKey: 0,
  };
  @visibleForTesting
  static const onlineNode = 'online';
  @visibleForTesting
  static const usersAdditionalDataKey = 'users_additional_data';
  @visibleForTesting
  static const rideCountHistoryKey = 'ride_count_history';

  static final FirebaseUserRepository _singleton =
      FirebaseUserRepository._internal();

  factory FirebaseUserRepository() => _singleton;

  FirebaseUserRepository._internal()
      : _realTimeDatabaseReference = FirebaseDatabase.instance.reference(),
        _firebaseFirestore = FirebaseFirestore.instance {
    SharedPreferences.getInstance().then((value) => _sharedPreferences = value);
    _setupFirestore();
  }

  @visibleForTesting
  FirebaseUserRepository.forTest({
    @required FirebaseDatabase realTimeDatabase,
    @required FirebaseFirestore firestoreDatabase,
    @required SharedPreferences sharedPreferences,
  })  : _realTimeDatabaseReference = realTimeDatabase?.reference() ??
            FirebaseDatabase.instance.reference(),
        _firebaseFirestore = firestoreDatabase ?? FirebaseFirestore.instance {
    if (sharedPreferences == null) {
      SharedPreferences.getInstance()
          .then((value) => _sharedPreferences = value);
    } else {
      _sharedPreferences = sharedPreferences;
    }
    _setupFirestore();
  }

  void _setupFirestore() {
    _additionalDataReference =
        _firebaseFirestore.collection(usersAdditionalDataKey);
    _firebaseFirestore.settings = Settings(persistenceEnabled: false);
  }

  @override
  Future<Map<String, dynamic>> getAdditionalData(String userUid) async {
    try {
      // ! Cache data access error should not affect the program execution
      final cachedData = await _getCahedData().catchError((_) => null);
      if (cachedData != null) return cachedData;
      final document = await _additionalDataReference.doc(userUid).get();
      final documentData = document.data();
      await _updateCacheData(documentData).catchError((_) => null);
      return documentData;
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  Future<Map<String, dynamic>> _getCahedData() async {
    final userAdditionalData =
        _sharedPreferences.getString(usersAdditionalDataKey);
    return json.decode(userAdditionalData);
  }

  Future<void> _updateCacheData(Map<String, dynamic> data) async {
    final dataJson = json.encode(data);
    final dataIsSuccessfullySet =
        await _sharedPreferences.setString(usersAdditionalDataKey, dataJson);
    if (!dataIsSuccessfullySet) {
      // delete local data if it is not up to date, and retry if its fail.
      if (!(await _sharedPreferences.clear())) await _sharedPreferences.clear();
    }
  }

  @override
  Future<Map<String, double>> getLocation(String uid) async {
    try {
      final coordinates =
          await _realTimeDatabaseReference.child(onlineNode).child(uid).once();
      if (coordinates.value == null) return null;
      return _coordinatesStringToMap(coordinates.value);
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  Map<String, double> _coordinatesStringToMap(String coordinates) {
    final coordinatesList = coordinates.split('-');
    return {
      'latitude': double.tryParse(coordinatesList.first),
      'longitude': double.tryParse(coordinatesList.last)
    };
  }

  @override
  Future<void> setLocation({
    String town,
    String userUid,
    Map<String, double> gpsCoordinates,
  }) {
    // TODO: implement setLocation
    throw UnimplementedError();
  }

  String _coordinatesMapToString(Map<String, double> coordinates) {
    return '${coordinates["latitude"]}-${coordinates["longitude"]}';
  }

  @override
  Stream<Map<String, double>> getLocationStream(String userUid) async* {
    try {
      final locationStream =
          _realTimeDatabaseReference.child('$onlineNode/$userUid').onValue;
      await for (var event in locationStream) {
        yield _coordinatesStringToMap(event.snapshot.value);
      }
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  @override
  Future<void> initAdditionalData(String userUid) async {
    try {
      await _updateCacheData(initialAdditionalData).catchError((_) => null);
      await _additionalDataReference.doc(userUid).set(initialAdditionalData);
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  @override
  Future<void> updateAdditionalData({
    @required Map<String, dynamic> data,
    @required String userUid,
  }) async {
    try {
      await _updateCacheData(data).catchError((_) => null);
      await _additionalDataReference.doc(userUid).update(data);
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  @override
  Future<void> incrmentRideCount(String userId) async {
    try {
      var additionalData = await getAdditionalData(userId);
      additionalData[totalRideCountKey]++;
      await updateAdditionalData(data: additionalData, userUid: userId);
      await incrementTodaysRideCount();
    } catch (e) {
      throw UserDataAccessException.unknown();
    }
  }

  @override
  Future<void> deleteLocation(String userUid) {
    // TODO: implement deleteLocation
    throw UnimplementedError();
  }

  @override
  Future<void> updateLocation(
      {String town, String userUid, String gpsCoordinates}) {
    // TODO: implement updateLocation
    throw UnimplementedError();
  }

  @visibleForTesting
  Future<void> incrementTodaysRideCount() async {
    final todaysRideCountKey = generateKeyFromDateTime(DateTime.now());
    final rideCountHistoryJson =
        _sharedPreferences.getString(rideCountHistoryKey);
    final rideCountHistory = json.decode(rideCountHistoryJson);
    var todaysRideCount = rideCountHistory[todaysRideCountKey];
    todaysRideCount = (todaysRideCount ?? 0) + 1;
    rideCountHistory[todaysRideCountKey] = todaysRideCount;
    if (rideCountHistory.length >= 50) {
      clearHistoryOlderThanOneMonth(rideCountHistory);
    }
    await _sharedPreferences.setString(
        rideCountHistoryKey, json.encode(rideCountHistory));
  }

  @override
  Map<String, dynamic> getRideCountHistory() {
    // TODO: make surpport return type [Map<String, int>]
    return json.decode(
      _sharedPreferences.getString(rideCountHistoryKey) ??
          _initializeRideCountHistory(),
    );
  }

  String _initializeRideCountHistory() {
    final rideCountHistoryJson = json.encode({
      generateKeyFromDateTime(DateTime.now()): 0,
    });
    _sharedPreferences.setString(rideCountHistoryKey, rideCountHistoryJson);
    return rideCountHistoryJson;
  }

  @visibleForTesting
  void clearHistoryOlderThanOneMonth(
      Map<String, dynamic> globalRideCountHistory) {
    // TODO: optimize
    final todayDate = DateTime.now();
    globalRideCountHistory.removeWhere((historyDate, _) {
      final currentHistoryDate = DateTime.parse(historyDate);
      return todayDate.difference(currentHistoryDate).inDays > 30;
    });
  }

  @override
  String getTheRecentlyWonTrophies(String userTrophies) {
    var trophiesWon = '';
    var userRideCountSinceXDays;
    UserRepository.trophiesList.forEach((trophyLevel, trophy) async {
      userRideCountSinceXDays =
          userRideCountFromFewDaysToToday(trophy.timeLimit?.inDays);
      if (!userTrophies.contains(trophyLevel) &&
          userRideCountSinceXDays >= trophy.minRideCount) {
        trophiesWon += trophyLevel;
      }
    });
    return trophiesWon;
  }

  @visibleForTesting
  int userRideCountFromFewDaysToToday(int numberOfDays) {
    if (numberOfDays == null) {
      return _sharedPreferences.getInt(totalRideCountKey);
    }
    var rideCountSinceXDays = 0;
    final todaysDate = DateTime.now();
    final rideCountHistoryJson =
        _sharedPreferences.getString(rideCountHistoryKey);
    final rideCountHistory = json.decode(rideCountHistoryJson);
    var currentHistoryDate;
    var currentHistoryKey;
    while (numberOfDays-- > 0) {
      currentHistoryDate = todaysDate.subtract(Duration(days: numberOfDays));
      currentHistoryKey = generateKeyFromDateTime(currentHistoryDate);
      rideCountSinceXDays += rideCountHistory[currentHistoryKey] ?? 0;
    }
    return rideCountSinceXDays;
  }

  // @override
  // Future<void> setReview({@required String userId, @required String review}) {
  //   _additionalDataReference.doc('$userId/$reviewsKey').
  // }
}

// TODO: implement better exception handler.

// dynamic _convertException(dynamic exception) {
//   switch (exception.runtimeType) {
//     case DatabaseError:
//     case FirebaseException:
//       return UserDataAccessException.unknown();
//       break;
//     default:
//       return exception; // <=> rethrow
//   }
// }
