abstract class User {
  String get photoUrl;
  String get uid;
  String get userName;
  String get phoneNumber;
  String get email;
  String get trophies;
  String get rideCount;
  String get formatedName;
  Future<void> refreshAdditionalData();
}
