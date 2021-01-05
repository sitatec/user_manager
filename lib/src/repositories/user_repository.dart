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

  String getTheRecentlyWonTrophies(String userTrophies);

  Future<void> incrmentRideCount(String userId);

  // static const trophiesNames = {
  //   'A': '7 trajets depuis votre inscription',
  //   'B': '5 trajets en une journée',
  //   'C': '35 trajets en une 4 jours',
  //   'D': '50 trajets en 5 jours',
  //   'E': '18+ trajets en une journée',
  //   'F': '80 trajets en une semaine',
  //   'G': '100+ trajets en une semaine',
  //   'H': '1000+ trajets depuis votre inscription'
  // };

  static const trophiesList = {
    'A': _TrophyModel(
      minRideCount: 5,
      name: '5 trajets depuis votre inscription',
      timeLimit: null,
    ),
    'B': _TrophyModel(
      minRideCount: 3,
      name: '3 trajets en une journée',
      timeLimit: Duration(days: 1),
    ),
    'C': _TrophyModel(
      timeLimit: Duration(days: 4),
      name: '15 trajets en 4 jours',
      minRideCount: 15,
    ),
    'D': _TrophyModel(
      timeLimit: Duration(days: 5),
      name: '28 trajets en 5 jours',
      minRideCount: 28,
    ),
    'E': _TrophyModel(
      timeLimit: Duration(days: 1),
      name: '8 trajets en une journée',
      minRideCount: 8,
    ),
    'F': _TrophyModel(
      timeLimit: Duration(days: 7),
      name: '45 trajets en une semaine',
      minRideCount: 45,
    ),
    'G': _TrophyModel(
      timeLimit: Duration(days: 7),
      minRideCount: 70,
      name: '70 trajets en une semaine',
    ),
    'H': _TrophyModel(
      timeLimit: null,
      minRideCount: 600,
      name: '600 trajets depuis votre inscription',
    )
  };
}

class _TrophyModel {
  final int minRideCount;
  final String name;
  final Duration timeLimit;
  const _TrophyModel(
      {@required this.minRideCount,
      @required this.timeLimit,
      @required this.name});
}
