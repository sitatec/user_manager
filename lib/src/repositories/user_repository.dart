import 'package:meta/meta.dart';
import '../firebase_gateways/firebase_user_repository.dart';

abstract class UserRepository {
  /// The UserRepository singleton
  static UserRepository get instance => FirebaseUserRepository();

  /// Returns the user additionals data in the type of `Map<String, String>` such as ride count, trophies...
  Future<Map<String, dynamic>> getAdditionalData(String userUid);

  /// Updates the user additional [data] such as ride count, trophies...
  Future<void> updateAdditionalData(
      {@required Map<String, dynamic> data, @required String userUid});

  /// Updates the [location] of the user
  Future<void> updateLocation(
      {@required String town,
      @required String userUid,
      @required String gpsCoordinates});

  /// Returns The location of user which unique Id is passed in [userUid] parameter
  Future<Map<String, double>> getLocation(String userUid);

  /// Returns The location stream of user which unique Id is passed in [userUid] parameter
  Stream<Map<String, double>> getLocationStream(String userUid);

  /// Initializes the user additionale data .
  Future<void> initAdditionalData(String userUid);

  /// Sets the user [location].
  Future<void> setLocation(
      {@required String town,
      @required String userUid,
      @required Map<String, double> gpsCoordinates});

  Future<void> deleteLocation(String userUid);
}
