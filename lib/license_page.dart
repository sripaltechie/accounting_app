import 'package:flutter/material.dart';
import 'license_service.dart';

class AppActivationPage extends StatefulWidget {
  @override
  _AppActivationPageState createState() => _AppActivationPageState();
}

class _AppActivationPageState extends State<AppActivationPage> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String _deviceId = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  void _loadId() async {
    String id = await LicenseService.getDeviceId();
    setState(() => _deviceId = id);
  }

  void _activate() async {
    setState(() => _isLoading = true);
    final result = await LicenseService.activateKey(_keyController.text.trim());
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // Success! Go to Dashboard/Login
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Activation Successful!"),
          backgroundColor: Colors.green));
      Navigator.pushReplacementNamed(context, '/'); // Go back to login
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error'] ?? "Failed"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.redAccent),
            SizedBox(height: 20),
            Text("License Expired",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Device ID: $_deviceId", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 30),
            TextField(
              controller: _keyController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.blueGrey[800],
                labelText: "Enter License Key",
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _activate,
                    child: Text("ACTIVATE"),
                    style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50)),
                  ),
          ],
        ),
      ),
    );
  }
}
