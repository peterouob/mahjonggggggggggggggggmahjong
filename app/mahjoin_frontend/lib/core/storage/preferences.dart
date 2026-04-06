import 'package:shared_preferences/shared_preferences.dart';

/// Persists session data across app restarts using SharedPreferences.
class Preferences {
  Preferences._();

  static const _keyUserId = 'session_user_id';
  static const _keyUserName = 'session_user_name';

  static Future<void> saveSession(String userId, String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserName, userName);
  }

  static Future<({String? userId, String? userName})> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      userId: prefs.getString(_keyUserId),
      userName: prefs.getString(_keyUserName),
    );
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
  }
}
