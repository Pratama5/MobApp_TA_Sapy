// lib/services/server_pinger.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:wavemark_app_v1/etc/app_settings.dart'; // Adjust path as needed

class ServerPinger {
  static Future<bool> ping() async {
    try {
      final String serverIp = await AppSettings.getServerIp();
      final Uri pingUri =
          Uri.parse("http://$serverIp:8000/ping"); // Assuming port 8000

      print("Pinging server at: $pingUri");
      final response =
          await http.get(pingUri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'ok' &&
            responseBody['message'] == 'pong') {
          print("Ping successful: Server responded with pong!");
          return true;
        } else {
          print(
              "Ping successful (status 200) but unexpected response body: ${response.body}");
          return true;
        }
      } else {
        print(
            "Ping failed: Server responded with status code ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Ping failed with error: $e");
      return false;
    }
  }
}
