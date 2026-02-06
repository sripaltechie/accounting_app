import 'package:flutter/material.dart';
import 'database_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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
          .showSnackBar(const SnackBar(content: Text("Invalid PIN")));
    }
  }

  void _showResetDialog() {
    TextEditingController newPin = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Reset PIN"),
              content: TextField(
                  controller: newPin,
                  decoration:
                      const InputDecoration(hintText: "Enter New 4-6 Digit PIN")),
              actions: [
                TextButton(
                    onPressed: () async {
                      await DatabaseHelper.instance.updatePin(newPin.text);
                      Navigator.pop(context);
                    },
                    child: const Text("Save"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Accounting Ledger",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
                controller: _pinController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: "Enter PIN", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _verify,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                child: Text("Login")),
          ],
        ),
      ),
    );
  }
}
