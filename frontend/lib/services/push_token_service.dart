import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/main.dart';

class PushTokenService {
  static Future<void> registerDeviceToken() async {
    print("🚀 registerDeviceToken() triggered");

    final prefs = await SharedPreferences.getInstance();
    String? jwt = prefs.getString("access_token");

    // No login yet → skip silently
    if (jwt == null) {
      print("⚠️ No JWT — skipping FCM registration");
      return;
    }

    // Refresh JWT if expired
    if (!await AuthService().isTokenValid()) {
      print("🔄 Access Token expired → refreshing...");
      jwt = await AuthService().refreshAccessToken();

      if (jwt == null) {
        print("❌ Refresh failed — skipping push token update");
        return;
      }
    }

    String? token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print("⚠️ No FCM Token yet — will auto retry later");
      return;
    }

    print("📲 FCM TOKEN: $token");

    try {
      final response = await http.post(
        Uri.parse(
          "https://turf-mgmt-sys.onrender.com/api/notifications/register/",
        ),
        headers: {
          "Authorization": "Bearer $jwt",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"device_token": token, "device_type": "android"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🔥 Token Registered OK");
      } else {
        print(
          "❌ Device Token Register Failed → ${response.statusCode} ${response.body}",
        );
      }
    } catch (e) {
      print("⚠️ Device Token Register Error: $e");
    }
  }
}
