import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_manager/src/exceptions/user_data_access_exception.dart';
import '../repositories/user_repository_interface.dart';

class UserRepository implements UserRepositoryInterface {
  final DatabaseReference _realTimeDatabaseReference;
  CollectionReference _additionalDataReference;
  final FirebaseFirestore _firebaseFirestore;
  SharedPreferences _sharedPreferences;
  @visibleForTesting
  static const onlineNode = 'online';
  static const trophiesNode = 't';
  static const rideCountNode = 'r';
  static const initialAdditionalData = {trophiesNode: null, rideCountNode: 0};
  @visibleForTesting
  static const usersAdditionalDataReference = 'users_additional_data';

  UserRepository({
    FirebaseDatabase realTimeDatabase,
    FirebaseFirestore firestoreDatabase,
    SharedPreferences sharedPreferences,
  })  : _realTimeDatabaseReference = realTimeDatabase?.reference() ??
            FirebaseDatabase.instance.reference(),
        _firebaseFirestore = firestoreDatabase ?? FirebaseFirestore.instance {
    if (sharedPreferences == null) {
      SharedPreferences.getInstance()
          .then((value) => _sharedPreferences = value);
    } else {
      _sharedPreferences = sharedPreferences;
    }
    _additionalDataReference =
        _firebaseFirestore.collection(usersAdditionalDataReference);
    _firebaseFirestore.settings = Settings(persistenceEnabled: false);
    _firebaseFirestore.disableNetwork();
  }

  @override
  Future<Map<String, dynamic>> getAdditionalData(String userUid) async {
    try {
      // ! Cache data access error should not affect the program execution
      final cachedData = await _getCahedData().catchError((_) => null);
      if (cachedData != null) return cachedData;
      await _firebaseFirestore.enableNetwork();
      final document = await _additionalDataReference.doc(userUid).get();
      final documentData = document.data();
      await _firebaseFirestore.disableNetwork();
      unawaited(_updateCacheData(documentData).catchError((_) => null));
      return documentData;
    } catch (e) {
      throw _convertException(e);
    }
  }

  Future<Map<String, dynamic>> _getCahedData() async {
    final trophies = _sharedPreferences.getString(trophiesNode);
    final rideCount = _sharedPreferences.getInt(rideCountNode);
    if (rideCount == null || trophies == null) return null;
    return {trophiesNode: trophies, rideCountNode: rideCount};
  }

  Future<void> _updateCacheData(Map<String, dynamic> data) async {
    final trophiesDataIsSet =
        await _sharedPreferences.setString(trophiesNode, data[trophiesNode]);
    final rideCountDataIsSet =
        await _sharedPreferences.setInt(rideCountNode, data[rideCountNode]);
    if (!trophiesDataIsSet || !rideCountDataIsSet) {
      // delete local data if it is not up to date.
      await _sharedPreferences.clear();
      // TODO : add force reload data button in the ui (for clearing local data , fetching remote data and update local data).
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
      throw _convertException(e);
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
      throw _convertException(e);
    }
  }

  @override
  Future<void> initAdditionalData(String userUid) async {
    try {
      unawaited(
        _updateCacheData(initialAdditionalData).catchError((_) => null),
      );
      await _firebaseFirestore.enableNetwork();
      await _additionalDataReference.doc(userUid).set(initialAdditionalData);
      await _firebaseFirestore.disableNetwork();
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> updateAdditionalData({
    Map<String, dynamic> data,
    String userUid,
  }) async {
    try {
      unawaited(_updateCacheData(data).catchError((_) => null));
      await _firebaseFirestore.enableNetwork();
      await _additionalDataReference.doc(userUid).update(data);
      await _firebaseFirestore.disableNetwork();
    } catch (e) {
      throw _convertException(e);
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

  dynamic _convertException(dynamic exception) {
    switch (exception.runtimeType) {
      case DatabaseError:
      case FirebaseException:
        return UserDataAccessException.unknown();
        break;
      default:
        return exception; // <=> rethrow
    }
  }
}
