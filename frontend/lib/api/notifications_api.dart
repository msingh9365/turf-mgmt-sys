import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Map<String, dynamic>>> fetchNotificationsFromBackend() async {
  final prefs = await SharedPreferences.getInstance();
  final jwt = prefs.getString('access_token');
  if (jwt == null) return [];

  final resp = await http.get(
    Uri.parse('https://turf-mgmt-sys.onrender.com/api/notifications/'),
    headers: {'Authorization': 'Bearer $jwt'},
  );

  if (resp.statusCode != 200) return [];

  final List<dynamic> data = jsonDecode(resp.body);
  return data.map<Map<String, dynamic>>((n) {
    return {
      'id': n['id'],
      'title': (n['title'] ?? 'Notification').toString(),
      'message': (n['body'] ?? '').toString(),
      'time': (n['created_at'] ?? '').toString(),
      'is_read': n['is_read'] ?? false,
      'data': n['data'], // keep raw payload if you need deep-links
    };
  }).toList();
}
