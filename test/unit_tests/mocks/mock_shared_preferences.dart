import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {
  static var data = <String, dynamic>{};
  static var enabled = false;
  static var throwException = false;
  static var writingDataWillFail = false;
  static var thrownExceptionCount = 0;

  @override
  Future<bool> clear() {
    data.clear();
    return Future.value(true);
  }

  @override
  String getString(String key) {
    if (!enabled) return null;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    }
    return data[key];
  }

  @override
  Future<bool> setString(String key, String value) {
    if (!enabled) return null;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    } else if (writingDataWillFail) return Future.value(false);
    data[key] = value;
    return Future.value(true);
  }

  @override
  int getInt(String key) {
    if (!enabled) return null;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    }
    return data[key];
  }

  @override
  Future<bool> setInt(String key, int value) {
    if (!enabled) return null;
    if (throwException) {
      thrownExceptionCount++;
      throw Exception();
    } else if (writingDataWillFail) return Future.value(false);
    data[key] = value;
    return Future.value(true);
  }

  // void setMockData(Map<String, dynamic> data) => data = data;
}
