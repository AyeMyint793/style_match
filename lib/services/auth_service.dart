import 'package:shared_preferences/shared_preferences.dart';

/// A professional service to handle user session persistence.
/// This encapsulates all logic related to "remembering" the user.
class AuthService {
  static const String _keyIsLoggedIn = "is_logged_in";
  static const String _keyUserEmail = "user_email";

  /// Persists the user's login state and email.
  static Future<void> login(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
  }

  /// Clears the user's session from the device.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUserEmail);
  }

  /// Checks if a valid session exists.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  /// Retrieves the currently logged-in user's email.
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }
}
