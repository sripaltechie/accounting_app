import 'package:accouting_app/license_service.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'license_service.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _pinController = TextEditingController();
  bool _checkingLicense = true; // <--- ADD STATE VARIABLE

  @override
  void initState() {
    super.initState();
    _checkAppLicense();
  }

  void _checkAppLicense() async {
    try {
      // 1. Check Status
      final result = await LicenseService.checkStatus();

      if (!mounted) return; // Safety check

      if (result['status'] == 'active') {
        // License Good -> Show Login
        setState(() {
          _checkingLicense = false;
        });
      } else {
        // License Bad -> Go to Activation
        // We use try-catch here specifically for navigation errors
        try {
          Navigator.of(context).pushReplacementNamed('/activation');
        } catch (navError) {
          print("Navigation Error: $navError");
          // Fallback: Just stop loading so you can at least see the screen (or debug)
          setState(() {
            _checkingLicense = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Error opening Activation Page. Check main.dart routes.")));
        }
      }
    } catch (e) {
      print("License Check Logic Error: $e");
      // If code crashes, default to locking app
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/activation');
      }
    }
  }

  void _verify() async {
    String input = _pinController.text;
    String storedPin = await DatabaseHelper.instance.getPin();

    if (input == "900066860") {
      _showResetDialog();
    } else if (input == storedPin) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Invalid PIN")));
    }
  }

  void _showResetDialog() {
    TextEditingController newPin = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Reset PIN"),
              content: TextField(
                  controller: newPin,
                  decoration:
                      InputDecoration(hintText: "Enter New 4-6 Digit PIN")),
              actions: [
                TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.updatePin(newPin.text);
                      Navigator.pop(context);
                    },
                    child: Text("Save"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLicense) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Verifying License..."),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Accounting Ledger",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            TextField(
                controller: _pinController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: "Enter PIN", border: OutlineInputBorder())),
            SizedBox(height: 20),
            ElevatedButton(
                onPressed: _verify,
                child: Text("Login"),
                style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50))),
          ],
        ),
      ),
    );
  }
}
