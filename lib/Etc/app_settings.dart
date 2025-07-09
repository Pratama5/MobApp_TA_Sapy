import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String serverIpKey = 'server_ip';
  static const String defaultServerIp = '192.168.1.100';

  static const String accessTokenKey = 'access_token';
  static const String userIdKey = 'user_id';

  // ✅ Get saved server IP
  static Future<String> getServerIp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(serverIpKey) ?? defaultServerIp;
  }

  // ✅ Get saved access token (for authorization header)
  static Future<String> getAccessToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey) ?? "";
  }

  // ✅ Get saved user ID (for uploaded_by field)
  static Future<String> getUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(userIdKey) ?? "";
  }
}
