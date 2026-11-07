import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences` held in memory, starting from [values].
///
/// Replaces the instance of the previous call, so each test starts clean.
Future<SharedPreferences> useMemoryPreferences([
  Map<String, Object> values = const {},
]) {
  // ignore: invalid_use_of_visible_for_testing_member, this package is test code.
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
