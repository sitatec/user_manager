import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database_mocks/firebase_database_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_repository.dart';
import 'package:user_manager/src/repositories/user_repository.dart';

import 'mocks/mock_shared_preferences.dart';

class _MockFirestoreInstance extends MockFirestoreInstance {
  static var networkIsEnabled = false;
  static var networkStateLog = <String>[];
  @override
  Future<void> disableNetwork() async {
    networkStateLog.add('disabled');
    networkIsEnabled = false;
  }

  @override
  Future<void> enableNetwork() async {
    networkStateLog.add('enabled');
    networkIsEnabled = true;
  }
}

void main() {
  FirebaseFirestore firebaseFirestore;
  UserRepository userRepository;
  FirebaseDatabase firebaseDatabase;
  SharedPreferences sharedPreferences;
  CollectionReference userAdditionalDataCollection;
  const userUid = 'testUid';
  const newUserUid = 'testNewUid';
  const userAdditionalData = {
    FirebaseUserRepository.rideCountNode: 45,
    FirebaseUserRepository.trophiesNode: 'Ac4'
  };
  setUp(() async {
    sharedPreferences = MockSharedPreferences();
    firebaseFirestore = _MockFirestoreInstance();
    firebaseDatabase = MockFirebaseDatabase.instance;
    userRepository = FirebaseUserRepository.forTest(
        firestoreDatabase: firebaseFirestore,
        realTimeDatabase: firebaseDatabase,
        sharedPreferences: sharedPreferences);
    userAdditionalDataCollection = await firebaseFirestore
        .collection(FirebaseUserRepository.usersAdditionalDataReference);
    await userAdditionalDataCollection.doc(userUid).set(userAdditionalData);
  });
  group('FirebaseUserTransformer Additional data : ', () {
    // test(
    //     'FirebaseFirestore instence should be created intrnally if not injected',
    //     () {
    //   expect(FirebaseUserRepository(), isNot(throwsException));
    // });

    test(
        'Should be returns additional data of user which uid is given in parameter.',
        () async {
      expect(
        await userRepository.getAdditionalData(userUid),
        equals(userAdditionalData),
      );
    });

    test(
        'Should returns null when nonexistent document id is passed in parameter.',
        () async {
      expect(await userRepository.getAdditionalData('fakeId'), isNull);
    });

    test(
        'Should initialize additional data of user which uid is given in parameter.',
        () async {
      final getNewUserData =
          () async => await userAdditionalDataCollection.doc(newUserUid).get();
      expect(
        (await getNewUserData()).exists,
        isFalse,
        reason: "Document with ID '$newUserUid' should'nt exists yet.",
      );
      await userRepository.initAdditionalData(newUserUid);
      expect(
        (await getNewUserData()).exists,
        isTrue,
        reason:
            "Document with ID '$newUserUid' should be created by the above instruction.",
      );
      expect((await getNewUserData()).data(),
          equals(FirebaseUserRepository.initialAdditionalData));
    });

    test(
        'Should update additional data of user which uid is given in parameter',
        () async {
      const updatedUserAdditionalData = {
        FirebaseUserRepository.rideCountNode: 645,
        FirebaseUserRepository.trophiesNode: 'other_Ac4'
      };
      final getUserData =
          () async => await userAdditionalDataCollection.doc(userUid).get();
      expect((await getUserData()).data(), equals(userAdditionalData));
      await userRepository.updateAdditionalData(
        data: updatedUserAdditionalData,
        userUid: userUid,
      );
      expect((await getUserData()).data(), equals(updatedUserAdditionalData));
      expect((await getUserData()).data(), isNot(userAdditionalData));
      //we never know ^ ;-)
    });
  });

  group('Taxi driver infos :', () {
    // Driver infos such as online, current location...
    const coordinates = {'latitude': 14.463742, 'longitude': 11.631249};
    const otherCoordinates = {'latitude': 16.403942, 'longitude': 10.038241};
    MockFirebaseDatabase.instance
        .reference()
        .child(FirebaseUserRepository.onlineNode)
        .set({
      userUid: '${coordinates['latitude']}-${coordinates['longitude']}',
      newUserUid:
          '${otherCoordinates['latitude']}-${otherCoordinates['longitude']}'
    });
    setUp(() {});
    test(
        'Should return the coordinates of user which uid is passed in parameter',
        () async {
      final _coordinates = await userRepository.getLocation(userUid);
      expect(_coordinates, equals(coordinates));
      final _othercoordinates = await userRepository.getLocation(newUserUid);
      expect(_othercoordinates, equals(otherCoordinates));
    });
    test(
        'Should returns null when nonexistent user uid is passed in parameter.',
        () async {
      final _othercoordinates = await userRepository.getLocation('fakeUid');
      expect(_othercoordinates, isNull);
    });

    test(
        'Should return a stream of coordinates of user whose uid is passed in parameter',
        () async {
      final _coordinatesStream = userRepository.getLocationStream(userUid);
      expect(_coordinatesStream, isA<Stream<Map<String, double>>>());
      expect(await _coordinatesStream.first, equals(coordinates));
    });
    // TODO: test write operations on taxi drivers information
  });
  group('Cache data (SharedPreferences) :', () {
    setUp(() {
      MockSharedPreferences.data.clear();
      MockSharedPreferences.enabled = true;
      _MockFirestoreInstance.networkStateLog.clear();
    });
    tearDownAll(() {
      MockSharedPreferences.enabled = false;
      MockSharedPreferences.data.clear();
    });
    tearDown(() {
      MockSharedPreferences.throwException = false;
      MockSharedPreferences.thrownExceptionCount = 0;
      MockSharedPreferences.writingDataWillFail = false;
    });

    test('Should not get remote data if local data is available', () async {
      await sharedPreferences.setString(
          FirebaseUserRepository.trophiesNode, 'test');
      await sharedPreferences.setInt(FirebaseUserRepository.rideCountNode, 4);
      await userRepository.getAdditionalData(userUid);
      // Firestore network must be enabled before fetching remote data so if
      // the [networkStateLog] doesn't contains [enabled] that means remote data
      // wasn't fetched.
      expect(
        _MockFirestoreInstance.networkStateLog.contains('enabled'),
        isFalse,
      );
    });

    test('Should get remote data if local data is not available', () async {
      await userRepository.getAdditionalData(userUid);
      expect(_MockFirestoreInstance.networkStateLog, contains('enabled'));
    });

    test('Should update local data when remote data is fetched', () async {
      expect(MockSharedPreferences.data, isEmpty);
      final remoteData = await userRepository.getAdditionalData(userUid);
      await Future.delayed(Duration.zero);
      expect(MockSharedPreferences.data, equals(remoteData));
    });

    test('Local data should be initialized while initializing remote data',
        () async {
      expect(MockSharedPreferences.data, isEmpty);
      await userRepository.initAdditionalData(userUid);
      expect(
        MockSharedPreferences.data,
        equals(FirebaseUserRepository.initialAdditionalData),
      );
    });

    test('Local data should be updated while updating remote data', () async {
      expect(MockSharedPreferences.data, isEmpty);
      await userRepository.updateAdditionalData(
        userUid: userUid,
        data: userAdditionalData,
      );
      expect(
        MockSharedPreferences.data,
        equals(userAdditionalData),
      );
    });

    test(
        'Exception thrown when getting local data should not affect the program execution',
        () async {
      MockSharedPreferences.throwException = true;
      expect(MockSharedPreferences.thrownExceptionCount, equals(0));
      expect(
        () async => await userRepository.getAdditionalData(userUid),
        returnsNormally,
      );
      await Future.delayed(Duration.zero);
      // [thrownExceptionCount] must be incremented the first time when
      // fetching local data and the second time when updating local data
      // because fetching local data should fail so [thrownExceptionCount] must contain 2;
      expect(MockSharedPreferences.thrownExceptionCount, 2);
    });

    test(
        'Exception thrown when updating local data should not affect the program execution',
        () async {
      MockSharedPreferences.throwException = true;
      expect(MockSharedPreferences.thrownExceptionCount, equals(0));
      expect(
        () async => await userRepository.updateAdditionalData(
          userUid: userUid,
          data: userAdditionalData,
        ),
        returnsNormally,
      );
      await Future.delayed(Duration.zero);
      expect(MockSharedPreferences.thrownExceptionCount, 1);
    });

    test(
        'Exception thrown when initializing local data should not affect the program execution',
        () async {
      MockSharedPreferences.throwException = true;
      expect(MockSharedPreferences.thrownExceptionCount, equals(0));
      expect(
        () async => await userRepository.initAdditionalData(userUid),
        returnsNormally,
      );
      await Future.delayed(Duration.zero);
      expect(MockSharedPreferences.thrownExceptionCount, 1);
    });
  });
  group('Firestore network handling', () {
    setUp(() {
      _MockFirestoreInstance.networkStateLog.clear();
      MockSharedPreferences.enabled =
          false; //local data must not be fetched otherwire network state will not change.
    });
    test(
        'Firestore network should be disabled when initializing [FirebaseUserRepository]',
        () {
      expect(_MockFirestoreInstance.networkStateLog, isEmpty);
      final _ = FirebaseUserRepository.forTest(
        firestoreDatabase: firebaseFirestore,
        realTimeDatabase: firebaseDatabase,
        sharedPreferences: sharedPreferences,
      );
      expect(_MockFirestoreInstance.networkStateLog, equals(['disabled']));
    });

    test(
        'When getting data, firestore network should be enabled first and then disabled after remote data fetching finish',
        () async {
      expect(_MockFirestoreInstance.networkStateLog, isEmpty);
      await userRepository.getAdditionalData(userUid);
      expect(
        _MockFirestoreInstance.networkStateLog,
        equals(['enabled', 'disabled']),
      );
    });

    test(
        'When updating data, firestore network should be enabled first and then disabled after remote data fetching finish',
        () async {
      expect(_MockFirestoreInstance.networkStateLog, isEmpty);
      await userRepository.updateAdditionalData(
        userUid: userUid,
        data: userAdditionalData,
      );
      expect(
        _MockFirestoreInstance.networkStateLog,
        equals(['enabled', 'disabled']),
      );
    });

    test(
        'When initializing data, firestore network should be enabled first and then disabled after remote data fetching finish',
        () async {
      expect(_MockFirestoreInstance.networkStateLog, isEmpty);
      await userRepository.initAdditionalData(userUid);
      expect(
        _MockFirestoreInstance.networkStateLog,
        equals(['enabled', 'disabled']),
      );
    });
  });
}
