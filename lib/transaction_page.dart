import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final _partyController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _daysController = TextEditingController();

  String _dbDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Edit Mode variables
  bool _isEdit = false;
  int? _editId;
  bool _isInit = false; // Added flag to prevent data reset

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load arguments once to prevent resetting data when DatePicker closes
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        if (args.containsKey('data')) {
          final data = args['data'];
          _isEdit = true;
          _editId = data['id'];
          _partyController.text = data['party'];
          _amountController.text = data['amount'].toString();
          _notesController.text = data['notes'] ?? '';
          _daysController.text = (data['credit_period'] ?? '').toString();
          _dbDate = data['date'];
        }
      }
      _isInit = true;
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_dbDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dbDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _save(String type) async {
    if (_partyController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Fill Party & Amount")));
      return;
    }

    int? creditPeriod;
    if (_daysController.text.isNotEmpty) {
      creditPeriod = int.tryParse(_daysController.text);
    }

    // Auto-create party if not exists
    final partyExists = await DatabaseHelper.instance
        .getPartyByName(_partyController.text.trim());
    if (partyExists == null) {
      await DatabaseHelper.instance
          .insertParty({'name': _partyController.text.trim(), 'mobile': ''});
    }

    if (_isEdit) {
      await DatabaseHelper.instance.updateTransaction({
        'id': _editId,
        'party': _partyController.text.trim(),
        'amount': double.parse(_amountController.text),
        'notes': _notesController.text,
        'date': _dbDate,
        'credit_period': creditPeriod,
      });
    } else {
      await DatabaseHelper.instance.insertTransaction({
        'type': type,
        'party': _partyController.text.trim(),
        'amount': double.parse(_amountController.text),
        'notes': _notesController.text,
        'date': _dbDate,
        'credit_period': creditPeriod,
        'cleared': 0,
        'unallocated_amount': 0.0
      });
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? "Updated!" : "$type Saved!")));
  }

  @override
  Widget build(BuildContext context) {
    // Handle Arguments safely for the Title
    final args = ModalRoute.of(context)!.settings.arguments;
    String type = "";
    if (args is String)
      type = args;
    else if (args is Map) type = args['type'];

    String displayDate =
        DateFormat('dd-MM-yyyy').format(DateTime.parse(_dbDate));

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? "Edit $type Bill" : "Add $type Bill")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: ListView(
          children: [
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              title: Text("Bill Date: $displayDate",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Icon(Icons.calendar_today, color: Colors.indigo),
              onTap: _pickDate,
            ),
            SizedBox(height: 15),

            // Autocomplete Party
            Autocomplete<String>(
              optionsBuilder: (val) async => val.text == ''
                  ? []
                  : await DatabaseHelper.instance.getMatchingParties(val.text),
              onSelected: (val) => _partyController.text = val,
              fieldViewBuilder: (ctx, controller, focus, onSub) {
                if (controller.text != _partyController.text)
                  controller.text = _partyController.text;
                return TextField(
                    controller: controller,
                    focusNode: focus,
                    onChanged: (val) => _partyController.text = val,
                    decoration: InputDecoration(
                        labelText: "Party Name", border: OutlineInputBorder()));
              },
            ),
            SizedBox(height: 15),
            TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: "Total Amount", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: "Credit Period (Days)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timelapse))),
            SizedBox(height: 15),
            TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: "Notes", border: OutlineInputBorder())),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _save(type),
              child: Text(_isEdit ? "UPDATE BILL" : "SAVE BILL"),
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
