import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database_mocks/firebase_database_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_manager/src/firebase_gateways/user_repository.dart';
import 'package:user_manager/src/repositories/user_repository_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseMocks();
  Firebase.initializeApp();
  const userUid = 'testUid';
  const newUserUid = 'testNewUid';

  group('User Additional data : ', () {
    const userAdditionalData = {
      UserRepository.rideCountNode: 45,
      UserRepository.trophiesNode: 'Ac4'
    };

    FirebaseFirestore firebaseFirestore;
    UserRepositoryInterface userRepository;
    CollectionReference userAdditionalDataCollection;
    setUp(() async {
      firebaseFirestore = MockFirestoreInstance();

      userAdditionalDataCollection = await firebaseFirestore
          .collection(UserRepository.usersAdditionalDataReference);

      await userAdditionalDataCollection.doc(userUid).set(userAdditionalData);

      userRepository = UserRepository(firestoreDatabase: firebaseFirestore);
    });
    test(
        'FirebaseFirestore instence should be created intrnally if not injected',
        () {
      expect(UserRepository(), isNot(throwsException));
    });

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
          equals(UserRepository.initialAdditionalData));
    });

    test(
        'Should update additional data of user which uid is given in parameter',
        () async {
      const updatedUserAdditionalData = {
        UserRepository.rideCountNode: 645,
        UserRepository.trophiesNode: 'other_Ac4'
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
    FirebaseDatabase firebaseDatabase;
    UserRepository userRepository;
    const coordinates = {'latitude': 14.463742, 'longitude': 11.631249};
    const otherCoordinates = {'latitude': 16.403942, 'longitude': 10.038241};
    MockFirebaseDatabase.instance
        .reference()
        .child(UserRepository.onlineNode)
        .set({
      userUid: '${coordinates['latitude']}-${coordinates['longitude']}',
      newUserUid:
          '${otherCoordinates['latitude']}-${otherCoordinates['longitude']}'
    });
    setUp(() {
      firebaseDatabase = MockFirebaseDatabase.instance;
      userRepository = UserRepository(realTimeDatabase: firebaseDatabase);
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
  });
}
