import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // These constants MUST MATCH the ones used in your SettingsPage.dart when saving the IP
  static const String serverIpKey = 'server_ip'; // Key for SharedPreferences
  static const String defaultServerIp =
      '192.168.1.100'; // Default IP if none is set

  // Static method to get the saved server IP
  static Future<String> getServerIp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Retrieve the IP using the key, or return the default if not found
    return prefs.getString(serverIpKey) ?? defaultServerIp;
  }

  // Optional: If you also want a shared way to save, you can add it here too,
  // though your SettingsPage.dart already handles saving.
  // static Future<void> saveServerIp(String ip) async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(serverIpKey, ip);
  // }
}
