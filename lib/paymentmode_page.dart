import 'package:flutter/material.dart';
import 'database_helper.dart';

class PaymentModePage extends StatefulWidget {
  @override
  _PaymentModePageState createState() => _PaymentModePageState();
}

class _PaymentModePageState extends State<PaymentModePage> {
  List<String> _modes = [];

  @override
  void initState() {
    super.initState();
    _loadModes();
  }

  void _loadModes() async {
    final modes = await DatabaseHelper.instance.getPaymentModes();
    setState(() {
      _modes = modes;
    });
  }

  void _addMode() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Payment Mode"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "e.g., UPI, Bank Transfer"),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await DatabaseHelper.instance
                    .addPaymentMode(controller.text.trim());
                _loadModes();
                Navigator.pop(context);
              }
            },
            child: Text("Add"),
          )
        ],
      ),
    );
  }

  void _deleteMode(String name) async {
    if (name == 'Cash') {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cannot delete default 'Cash' mode")));
      return;
    }

    // Confirm delete
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete $name?"),
        content: Text("Are you sure you want to delete this payment mode?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deletePaymentMode(name);
              _loadModes();
              Navigator.pop(context);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payment Modes")),
      body: _modes.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _modes.length,
              itemBuilder: (context, index) {
                final mode = _modes[index];
                return ListTile(
                  leading: Icon(Icons.payment, color: Colors.indigo),
                  title: Text(mode),
                  trailing: mode == 'Cash'
                      ? Icon(Icons.lock, color: Colors.grey, size: 20)
                      : IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMode(mode),
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMode,
        child: Icon(Icons.add),
        tooltip: "Add New Mode",
      ),
    );
  }
}
