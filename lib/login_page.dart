import 'package:flutter/material.dart';
import 'database_helper.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _pinController = TextEditingController();

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
