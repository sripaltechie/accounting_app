import 'package:flutter/material.dart';
import 'license_service.dart';

class ActivationPage extends StatefulWidget {
  @override
  _ActivationPageState createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
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
    if (_keyController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final result = await LicenseService.activateKey(_keyController.text.trim());
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Activation Successful!"),
          backgroundColor: Colors.green));
      // Navigate back to login (root)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['error'] ?? "Failed"),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 80, color: Colors.amber),
            SizedBox(height: 20),
            Text("License Required",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Your Device ID:", style: TextStyle(color: Colors.white70)),
            Text(_deviceId,
                style: TextStyle(
                    color: Colors.amber,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            SizedBox(height: 30),
            TextField(
              controller: _keyController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.indigo[800],
                labelText: "Enter License Key",
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key, color: Colors.amber),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator(color: Colors.amber)
                : ElevatedButton(
                    onPressed: _activate,
                    child: Text("ACTIVATE APP"),
                    style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black),
                  ),
          ],
        ),
      ),
    );
  }
}
