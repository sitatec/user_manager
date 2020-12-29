import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:user_manager/src/exceptions/user_data_access_exception.dart';
import '../repositories/user_repository_interface.dart';

class UserRepository implements UserRepositoryInterface {
  final DatabaseReference _realTimeDatabaseReference;
  final CollectionReference _additionalDataReference;
  @visibleForTesting
  static const onlineNode = 'online';
  @visibleForTesting
  static const trophiesNode = 't';
  @visibleForTesting
  static const rideCountNode = 'r';
  @visibleForTesting
  static const initialAdditionalData = {trophiesNode: null, rideCountNode: 0};
  @visibleForTesting
  static const usersAdditionalDataReference = 'users_additional_data';

  UserRepository(
      {FirebaseDatabase realTimeDatabase, FirebaseFirestore firestoreDatabase})
      : _realTimeDatabaseReference = realTimeDatabase?.reference() ??
            FirebaseDatabase.instance.reference(),
        _additionalDataReference = firestoreDatabase
                ?.collection(usersAdditionalDataReference) ??
            FirebaseFirestore.instance.collection(usersAdditionalDataReference);

  @override
  Future<Map<String, dynamic>> getAdditionalData(String userUid) async {
    try {
      final userDocument = await _additionalDataReference.doc(userUid).get();
      return userDocument.data();
    } catch (e) {
      throw _convertException(e);
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
      await _additionalDataReference.doc(userUid).set(initialAdditionalData);
    } catch (e) {
      throw _convertException(e);
    }
  }

  @override
  Future<void> updateAdditionalData(
      {Map<String, dynamic> data, String userUid}) async {
    try {
      await _additionalDataReference.doc(userUid).update(data);
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
