import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database_mocks/firebase_database_mocks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_repository.dart';
import 'package:user_manager/src/repositories/user_repository.dart';
import 'package:user_manager/src/utils/utils.dart';

import '../mocks/mock_shared_preferences.dart';

void main() {
  FirebaseFirestore firebaseFirestore;
  UserRepository userRepository;
  FirebaseDatabase firebaseDatabase;
  SharedPreferences sharedPreferences;
  CollectionReference userAdditionalDataCollection;
  const userUid = 'testUid';
  const newUserUid = 'testNewUid';
  const userAdditionalData = {
    FirebaseUserRepository.totalRideCountKey: 45,
    FirebaseUserRepository.trophiesKey: 'Ac4',
  };
  setUp(() async {
    sharedPreferences = MockSharedPreferences();
    firebaseFirestore = MockFirestoreInstance();
    firebaseDatabase = MockFirebaseDatabase.instance;
    userRepository = FirebaseUserRepository.forTest(
        firestoreDatabase: firebaseFirestore,
        realTimeDatabase: firebaseDatabase,
        sharedPreferences: sharedPreferences);
    userAdditionalDataCollection = await firebaseFirestore
        .collection(FirebaseUserRepository.usersAdditionalDataKey);
    await userAdditionalDataCollection.doc(userUid).set(userAdditionalData);
  });
  group('Users Additional data : ', () {
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
        FirebaseUserRepository.totalRideCountKey: 645,
        FirebaseUserRepository.trophiesKey: 'other_Ac4',
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
      //we never know  ^  ;-)
    });
  });

/******************************************************************************/
/****************************** [ New Group ] *********************************/
/******************************************************************************/

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

/******************************************************************************/
/****************************** [ New Group ] *********************************/
/******************************************************************************/

  group('Cache data (SharedPreferences) :', () {
    setUp(() {
      MockSharedPreferences.data.clear();
      MockSharedPreferences.enabled = true;
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
      await firebaseFirestore.clearPersistence();
      final dataJson = json.encode({
        FirebaseUserRepository.trophiesKey: 'from_local_cache_data',
        FirebaseUserRepository.totalRideCountKey: 4,
      });
      await sharedPreferences.setString(
          FirebaseUserRepository.usersAdditionalDataKey, dataJson);
      expect(await userRepository.getAdditionalData(userUid),
          equals(json.decode(dataJson)));
    });

    test('Should get remote data if local data is not available', () async {
      expect(MockSharedPreferences.data, isEmpty);
      expect(await userRepository.getAdditionalData(userUid), isNotEmpty);
    });

    test('Should update local data when remote data is fetched', () async {
      expect(MockSharedPreferences.data, isEmpty);
      final remoteData = await userRepository.getAdditionalData(userUid);
      await Future.delayed(Duration.zero);
      expect(
          json.decode(MockSharedPreferences
              .data[FirebaseUserRepository.usersAdditionalDataKey]),
          equals(remoteData));
    });

    test('Local data should be initialized while initializing remote data',
        () async {
      expect(MockSharedPreferences.data, isEmpty);
      await userRepository.initAdditionalData(userUid);
      expect(
        json.decode(MockSharedPreferences
            .data[FirebaseUserRepository.usersAdditionalDataKey]),
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
        json.decode(MockSharedPreferences
            .data[FirebaseUserRepository.usersAdditionalDataKey]),
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

/******************************************************************************/
/****************************** [ New Group ] *********************************/
/******************************************************************************/

  group('Trophies and ride count history management :', () {
    //! In this group we need to use some methods that is not publicly exposed
    //! by the [UserRepository] class so we need to make a copy of original
    //! userRepository initialized in the global [setUp] function and cast it to
    //! [FirebaseUserRepository] which expose needed methods publicly for tests.
    FirebaseUserRepository userRepository2;
    Map<String, dynamic> rideCountHistory() => jsonDecode(
        MockSharedPreferences.data[FirebaseUserRepository.rideCountHistoryKey]);
    String dateOfXDaysAgo(int daysAgo) {
      final historyDate = DateTime.now().subtract(Duration(days: daysAgo));
      return generateKeyFromDateTime(historyDate);
    }

    setUp(() {
      userRepository2 = userRepository;
      MockSharedPreferences.enabled = true;
      MockSharedPreferences.data[FirebaseUserRepository.rideCountHistoryKey] =
          json.encode({
        dateOfXDaysAgo(0): 14,
        dateOfXDaysAgo(1): 6,
        dateOfXDaysAgo(2): 0,
        dateOfXDaysAgo(3): 23,
        dateOfXDaysAgo(4): 17,
        dateOfXDaysAgo(5): 0,
        dateOfXDaysAgo(6): 04
      });
      MockSharedPreferences.data[FirebaseUserRepository.totalRideCountKey] =
          100;
    });

    test('Should generate date in format yyyy-mm-dd ', () {
      String fixeTo2Digit(int number) {
        return number.toString().length < 2 ? '0$number' : '$number';
      }

      final now = DateTime.now();
      final generatedDate = generateKeyFromDateTime(now);
      expect(generatedDate,
          '${now.year}-${fixeTo2Digit(now.month)}-${fixeTo2Digit(now.day)}');
    });

    test('Should increment ride count', () async {
      await userRepository.incrmentRideCount(userUid);
      final additionalData = await userRepository.getAdditionalData(userUid);
      expect(
        additionalData[FirebaseUserRepository.totalRideCountKey],
        (userAdditionalData[FirebaseUserRepository.totalRideCountKey] as int) +
            1,
      );
    });

    test('should clear history older than one month', () {
      final rideCountHistoryContainingOld = <String, dynamic>{}
        ..addAll(rideCountHistory());
      // Add old history.
      rideCountHistoryContainingOld.addAll({
        '2019-01-04': 34,
        '2020-01-03': 6,
        '2020-06-02': 0,
        '2020-12-01': 23,
        '2020-12-03': 17,
        '2012-12-30': 0,
        '2017-12-29': 04
      });
      expect(rideCountHistoryContainingOld.length,
          greaterThan(rideCountHistory().length));
      userRepository2
          .clearHistoryOlderThanOneMonth(rideCountHistoryContainingOld);
      expect(rideCountHistoryContainingOld, equals(rideCountHistory()));
    });

    test('Should increment today\'s ride count', () async {
      final todayRideCountKey = DateTime.now().toString().split(' ').first;
      final todayRideCount = rideCountHistory()[todayRideCountKey] ?? 0;
      await userRepository2.incrementTodaysRideCount();
      expect(rideCountHistory()[todayRideCountKey], equals(todayRideCount + 1));
    });

    test('Should return ride count from a few days to today', () {
      // TODO: refactoring.
      //! The map keys used here most be the same to those used in data
      //! initialization in the [setUp()] function.
      var rideCountFrom3Days = rideCountHistory()[dateOfXDaysAgo(0)];
      rideCountFrom3Days += rideCountHistory()[dateOfXDaysAgo(1)];
      rideCountFrom3Days += rideCountHistory()[dateOfXDaysAgo(2)];
      expect(userRepository2.userRideCountFromFewDaysToToday(3),
          equals(rideCountFrom3Days));
    });

    test('Should return trophies that the user has recently won', () {
      //! To anderstand how the letters for the trophies level is choosed for
      //! the tests, see the [UserRepository] class which has a static
      //! [Map<String, _Trophy>].
      expect(userRepository.getTheRecentlyWonTrophies(''), equals('ABCDEF'));
      expect(userRepository.getTheRecentlyWonTrophies('A'), equals('BCDEF'));
      expect(userRepository.getTheRecentlyWonTrophies('AB'), equals('CDEF'));
      expect(userRepository.getTheRecentlyWonTrophies('DFA'), equals('BCE'));
      expect(userRepository.getTheRecentlyWonTrophies('CDEF'), equals('AB'));
    });

    test('Should return ride count history', () {
      final rideCountHistory = userRepository2.getRideCountHistory();
      final rideCountHistoryFromSharedPref = MockSharedPreferences
          .data[FirebaseUserRepository.rideCountHistoryKey];
      expect(
        rideCountHistory,
        equals(jsonDecode(rideCountHistoryFromSharedPref)),
      );
    });
  });
}

/******************************************************************************/
/****************************** [ New Group ] *********************************/
/******************************************************************************/

// group('Firestore network handling', () {
//   setUp(() {
//     _MockFirestoreInstance.networkStateLog.clear();
//     MockSharedPreferences.enabled =
//         false; //local data must not be fetched otherwire network state will not change.
//   });
//   test(
//       'Firestore network should be disabled when initializing [FirebaseUserRepository]',
//       () {
//     expect(_MockFirestoreInstance.networkStateLog, isEmpty);
//     final _ = FirebaseUserRepository.forTest(
//       firestoreDatabase: firebaseFirestore,
//       realTimeDatabase: firebaseDatabase,
//       sharedPreferences: sharedPreferences,
//     );
//     expect(_MockFirestoreInstance.networkStateLog, equals(['disabled']));
//   });

//   test(
//       'When getting data, firestore network should be enabled first and then disabled after remote data fetching finish',
//       () async {
//     expect(_MockFirestoreInstance.networkStateLog, isEmpty);
//     await userRepository.getAdditionalData(userUid);
//     expect(
//       _MockFirestoreInstance.networkStateLog,
//       equals(['enabled', 'disabled']),
//     );
//   });

//   test(
//       'When updating data, firestore network should be enabled first and then disabled after remote data fetching finish',
//       () async {
//     expect(_MockFirestoreInstance.networkStateLog, isEmpty);
//     await userRepository.updateAdditionalData(
//       userUid: userUid,
//       data: userAdditionalData,
//     );
//     expect(
//       _MockFirestoreInstance.networkStateLog,
//       equals(['enabled', 'disabled']),
//     );
//   });

//   test(
//       'When initializing data, firestore network should be enabled first and then disabled after remote data fetching finish',
//       () async {
//     expect(_MockFirestoreInstance.networkStateLog, isEmpty);
//     await userRepository.initAdditionalData(userUid);
//     expect(
//       _MockFirestoreInstance.networkStateLog,
//       equals(['enabled', 'disabled']),
//     );
//   });
// });

// class _MockFirestoreInstance extends MockFirestoreInstance {
//   static var networkIsEnabled = false;
//   static var networkStateLog = <String>[];
//   @override
//   Future<void> disableNetwork() async {
//     networkStateLog.add('disabled');
//     networkIsEnabled = false;
//   }

//   @override
//   Future<void> enableNetwork() async {
//     networkStateLog.add('enabled');
//     networkIsEnabled = true;
//   }
// }
