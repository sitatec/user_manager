import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_repository.dart';
import 'package:user_manager/src/firebase_gateways/firebase_user_interface.dart';
import 'package:user_manager/src/repositories/user_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockFirebaseUser extends Mock implements User {
  @override
  String get displayName => _name;
  static String _name = '';
  @override
  String get uid => 'uid';
}

void main() {
  final userRepository = MockUserRepository();
  FirebaseUserInterface user;
  void initUser() {
    when(userRepository.getAdditionalData(any)).thenAnswer(
        (_) => Future.value(FirebaseUserRepository.initialAdditionalData));
    user = FirebaseUserInterface(
      firebaseUser: MockFirebaseUser(),
      userRepository: userRepository,
    );
  }

  test('Should format user name', () {
    MockFirebaseUser._name = 'sita bérété';
    initUser();
    expect(user.formatedName, equals('Sita'));
  });
  test('Should format user name', () {
    MockFirebaseUser._name = 'elhadj sita berete';
    initUser();
    expect(user.formatedName, equals('Elhadj sita'));
  });
  test('Should format user name', () {
    MockFirebaseUser._name = 'Elhadj sita berete oteh sljfjsl';
    initUser();
    expect(user.formatedName, equals('Elhadj sita'));
  });

  test('Should format user name', () {
    MockFirebaseUser._name = 'berete';
    initUser();
    expect(user.formatedName, equals('Berete'));
  });
}
