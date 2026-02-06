import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String API_URL =
      'https://chandaservices.in/license-manager/api.php';

  // 1. Get or Generate Unique Device ID
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('app_device_id');
    if (id == null) {
      // Generate a random ID (e.g., user_abc123)
      String randomStr = Random().nextInt(999999).toString().padLeft(6, '0');
      id = 'user_$randomStr';
      await prefs.setString('app_device_id', id);
    }
    return id;
  }

  // 2. Check Status
  static Future<Map<String, dynamic>> checkStatus() async {
    try {
      String deviceId = await getDeviceId();
      final response = await http.post(
        Uri.parse(API_URL),
        body: jsonEncode({'action': 'check_status', 'user_id': deviceId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("License Check Error: $e");
    }
    // If error/offline, return null or handle gracefully
    // For strict security, return {'status': 'none'} on error
    return {'status': 'error'};
  }

  // 3. Activate Key
  static Future<Map<String, dynamic>> activateKey(String key) async {
    try {
      String deviceId = await getDeviceId();
      final response = await http.post(
        Uri.parse(API_URL),
        body: jsonEncode(
            {'action': 'activate', 'user_id': deviceId, 'license_key': key}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Server Error'};
  }
}
