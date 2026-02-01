import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatefulWidget {
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _partyController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _dbDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<String> _paymentModes = ['Cash'];
  String _selectedMode = 'Cash';

  List<Map<String, dynamic>> _pendingBills = [];
  Map<int, double> _allocations = {};
  bool _isLoadingBills = false;

  // Edit Mode
  bool _isEdit = false;
  int? _editId;

  @override
  void initState() {
    super.initState();
    _loadPaymentModes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEdit) {
      // Only load once
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map && args.containsKey('data')) {
        final data = args['data'];
        _isEdit = true;
        _editId = data['id'];
        _partyController.text = data['party'];
        _amountController.text = data['amount'].toString();
        _notesController.text = data['notes'] ?? '';
        _dbDate = data['date'];
        _selectedMode = data['payment_mode'] ?? 'Cash';
      }
    }
  }

  void _loadPaymentModes() async {
    final modes = await DatabaseHelper.instance.getPaymentModes();
    setState(() {
      _paymentModes = modes;
      if (!_paymentModes.contains(_selectedMode)) {
        _selectedMode = _paymentModes.isNotEmpty ? _paymentModes.first : 'Cash';
      }
    });
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

  Future<void> _fetchPendingBills() async {
    if (_partyController.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoadingBills = true);

    // Determine type
    final args = ModalRoute.of(context)!.settings.arguments;
    String type = (args is Map) ? args['type'] : args as String;

    List<Map<String, dynamic>> bills = await DatabaseHelper.instance
        .getPendingInvoices(_partyController.text.trim(), type);

    setState(() {
      _pendingBills = bills;
      _isLoadingBills = false;
      _allocations.clear();
    });
  }

  void _allocateAmount(int invoiceId, double maxPending) {
    setState(() {
      if (_allocations.containsKey(invoiceId)) {
        _allocations.remove(invoiceId);
      } else {
        double totalEntered = double.tryParse(_amountController.text) ?? 0.0;
        double alreadyUsed =
            _allocations.values.fold(0, (sum, item) => sum + item);
        double remaining = totalEntered - alreadyUsed;

        if (remaining <= 0) return;

        double toAllocate = remaining >= maxPending ? maxPending : remaining;
        _allocations[invoiceId] = toAllocate;
      }
    });
  }

  void _savePayment() async {
    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0 || _partyController.text.isEmpty) return;

    // Handle Arguments safely
    final args = ModalRoute.of(context)!.settings.arguments;
    String type = (args is Map) ? args['type'] : args as String;

    // Auto-create party
    final partyExists = await DatabaseHelper.instance
        .getPartyByName(_partyController.text.trim());
    if (partyExists == null) {
      await DatabaseHelper.instance
          .insertParty({'name': _partyController.text.trim(), 'mobile': ''});
    }

    if (_isEdit) {
      // Update basic info only (Allocations are preserved for simplicity in this version)
      // Recalculating allocations on edit is complex; we assume user deletes and re-enters if deep changes needed.
      // Here we just update the text fields.
      await DatabaseHelper.instance.updateTransaction({
        'id': _editId,
        'party': _partyController.text.trim(),
        'amount': totalAmount,
        'date': _dbDate,
        'notes': _notesController.text,
        'payment_mode': _selectedMode,
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Updated (Links preserved)")));
    } else {
      double allocatedTotal =
          _allocations.values.fold(0, (sum, item) => sum + item);
      List<Map<String, dynamic>> allocationList = [];
      _allocations.forEach((invId, amt) {
        allocationList.add({'invoice_id': invId, 'amount': amt});
      });

      await DatabaseHelper.instance.createPaymentWithAllocations({
        'type': type,
        'party': _partyController.text.trim(),
        'amount': totalAmount,
        'date': _dbDate,
        'notes': _notesController.text,
        'payment_mode': _selectedMode,
        'unallocated_amount': totalAmount - allocatedTotal,
        'cleared': 0
      }, allocationList);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Payment Saved!")));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    String type = (args is Map) ? args['type'] : args as String;

    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    double usedAmount = _allocations.values.fold(0, (sum, item) => sum + item);
    double remaining = totalAmount - usedAmount;

    String displayDate =
        DateFormat('dd-MM-yyyy').format(DateTime.parse(_dbDate));

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? "Edit $type" : "$type Entry")),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(15),
            color: Colors.blue[50],
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.indigo),
                      SizedBox(width: 8),
                      Text("Date: $displayDate",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Divider(),
                Autocomplete<String>(
                  optionsBuilder: (val) async => val.text == ''
                      ? []
                      : await DatabaseHelper.instance
                          .getMatchingParties(val.text),
                  onSelected: (val) {
                    _partyController.text = val;
                    if (!_isEdit) _fetchPendingBills();
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    if (controller.text != _partyController.text)
                      controller.text = _partyController.text;
                    return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (val) => _partyController.text = val,
                        decoration: InputDecoration(
                            labelText: "Party Name",
                            filled: true,
                            fillColor: Colors.white));
                  },
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: "Amount",
                            filled: true,
                            fillColor: Colors.white),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedMode,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: "Mode"),
                        items: _paymentModes
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedMode = val!),
                      ),
                    ),
                  ],
                ),
                if (!_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text("Used: ₹$usedAmount  |  Not Used: ₹$remaining",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: remaining < 0 ? Colors.red : Colors.green)),
                  ),
              ],
            ),
          ),

          // Only show pending bills allocation on CREATE, hide on EDIT to avoid complexity
          if (!_isEdit)
            Expanded(
              child: _isLoadingBills
                  ? Center(child: CircularProgressIndicator())
                  : _pendingBills.isEmpty
                      ? Center(
                          child: Text("No pending bills or select party first"))
                      : ListView.builder(
                          itemCount: _pendingBills.length,
                          itemBuilder: (context, index) {
                            var bill = _pendingBills[index];
                            bool isSelected =
                                _allocations.containsKey(bill['id']);
                            String bDate = DateFormat('dd-MM-yyyy')
                                .format(DateTime.parse(bill['date']));
                            return Card(
                              color:
                                  isSelected ? Colors.green[100] : Colors.white,
                              child: ListTile(
                                leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) => _allocateAmount(
                                        bill['id'], bill['pending_amount'])),
                                title: Text("Bill Date: $bDate"),
                                subtitle: Text(
                                    "Total: ₹${bill['amount']} | Pending: ₹${bill['pending_amount']}"),
                              ),
                            );
                          },
                        ),
            )
          else
            Expanded(
                child: Center(
                    child: Text(
                        "Editing Amount/Date only.\nDelete and Re-enter if allocations need change.",
                        textAlign: TextAlign.center))),

          Padding(
            padding: EdgeInsets.all(15),
            child: ElevatedButton(
              onPressed: _savePayment,
              child: Text(_isEdit ? "UPDATE" : "SAVE TRANSACTION"),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
          )
        ],
      ),
    );
  }
}
