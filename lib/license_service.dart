import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  // YOUR API URL
  static const String API_URL =
      'https://chandaservices.in/license-manager/api.php';

  /// 1. Get Hardware ID (Survives Reinstall)
  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // androidInfo.id is unique to the device + signing key
      return androidInfo.id;
    }
    return "unknown_device";
  }

  /// 2. Check Status (Online with Offline Fallback)
  static Future<Map<String, dynamic>> checkStatus() async {
    String deviceId = await getDeviceId();
    final prefs = await SharedPreferences.getInstance();

    try {
      // A. Try Online Check
      final response = await http.post(
        Uri.parse(API_URL),
        body: jsonEncode({'action': 'check_status', 'user_id': deviceId}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5)); // 5 second timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If active, save expiry to local storage for offline use
        if (data['status'] == 'active') {
          await prefs.setString('license_expiry', data['expiry']);
          await prefs.setString('license_status', 'active');
        } else {
          await prefs.setString('license_status', 'expired');
        }
        return data;
      }
    } catch (e) {
      print("Online check failed: $e");
    }

    // B. Offline Fallback
    // If internet fails, check local storage
    String? localExpiry = prefs.getString('license_expiry');
    if (localExpiry != null) {
      DateTime expiryDate = DateTime.parse(localExpiry);
      if (DateTime.now().isBefore(expiryDate)) {
        return {'status': 'active', 'expiry': localExpiry};
      }
    }

    return {
      'status': 'error',
      'message': 'Connection failed & no offline license found'
    };
  }

  /// 3. Activate Key
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
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Save locally immediately upon success
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('license_expiry', result['new_expiry']);
          await prefs.setString('license_status', 'active');
        }
        return result;
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Server Error'};
  }
}
