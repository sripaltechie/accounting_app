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

  // State for Linking
  List<Map<String, dynamic>> _pendingBills = [];
  Map<int, double> _allocations = {}; // invoice_id -> allocated_amount
  bool _isLoadingBills = false;

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
    FocusScope.of(context).unfocus(); // Close keyboard
    setState(() => _isLoadingBills = true);
    final String type = ModalRoute.of(context)!.settings.arguments as String;

    // Fetch bills from DB
    List<Map<String, dynamic>> bills = await DatabaseHelper.instance
        .getPendingInvoices(_partyController.text, type);

    setState(() {
      _pendingBills = bills;
      _isLoadingBills = false;
      _allocations.clear(); // Reset previous allocations
    });
  }

  void _allocateAmount(int invoiceId, double maxPending) {
    // Basic logic: Try to allocate full pending amount if payment pool allows
    // For this simple version, we toggle full allocation
    setState(() {
      if (_allocations.containsKey(invoiceId)) {
        _allocations.remove(invoiceId);
      } else {
        // Calculate remaining money in hand
        double totalEntered = double.tryParse(_amountController.text) ?? 0.0;
        double alreadyUsed =
            _allocations.values.fold(0, (sum, item) => sum + item);
        double remaining = totalEntered - alreadyUsed;

        if (remaining <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No amount left to allocate!")));
          return;
        }

        // Allocate lesser of (Remaining Hand Cash) OR (Bill Pending Amount)
        double toAllocate = remaining >= maxPending ? maxPending : remaining;
        _allocations[invoiceId] = toAllocate;
      }
    });
  }

  void _savePayment() async {
    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0 || _partyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Enter Party and valid Amount")));
      return;
    }

    double allocatedTotal =
        _allocations.values.fold(0, (sum, item) => sum + item);
    final String type = ModalRoute.of(context)!.settings.arguments as String;

    // Prepare Allocation List
    List<Map<String, dynamic>> allocationList = [];
    _allocations.forEach((invId, amt) {
      allocationList.add({'invoice_id': invId, 'amount': amt});
    });

    // Save to DB
    await DatabaseHelper.instance.createPaymentWithAllocations({
      'type': type,
      'party': _partyController.text,
      'amount': totalAmount,
      'date': _dbDate,
      'notes': _notesController.text,
      'unallocated_amount': totalAmount - allocatedTotal,
      'cleared': 0 // Not relevant for payment record itself
    }, allocationList);

    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Payment Saved & Linked!")));
  }

  @override
  Widget build(BuildContext context) {
    final String type = ModalRoute.of(context)!.settings.arguments as String;
    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    double usedAmount = _allocations.values.fold(0, (sum, item) => sum + item);
    double remaining = totalAmount - usedAmount;

    String displayDate =
        DateFormat('dd-MM-yyyy').format(DateTime.parse(_dbDate));

    return Scaffold(
      appBar: AppBar(title: Text("$type Entry")),
      body: Column(
        children: [
          // 1. Top Section: Details
          Container(
            padding: EdgeInsets.all(15),
            color: Colors.blue[50],
            child: Column(
              children: [
                Row(
                  children: [
                    // Date Picker Row
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
                          Spacer(),
                          Text("Change", style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                    Divider(),

                    // Autocomplete for Party Name
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder:
                            (TextEditingValue textEditingValue) async {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return await DatabaseHelper.instance
                              .getMatchingParties(textEditingValue.text);
                        },
                        onSelected: (String selection) {
                          _partyController.text = selection;
                          _fetchPendingBills(); // Auto-fetch when selected from list
                        },
                        fieldViewBuilder: (context, textEditingController,
                            focusNode, onFieldSubmitted) {
                          // Sync the autocomplete controller with our logic controller
                          if (textEditingController.text !=
                              _partyController.text) {
                            textEditingController.text = _partyController.text;
                          }

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: (val) => _partyController.text = val,
                            decoration: const InputDecoration(
                                labelText: "Party Name",
                                filled: true,
                                fillColor: Colors.white,
                                hintText: "Start typing..."),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: _fetchPendingBills,
                      tooltip: "Fetch Pending Bills",
                    )
                  ],
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: "Amount Received/Paid",
                      filled: true,
                      fillColor: Colors.white),
                  onChanged: (val) => setState(() {}),
                ),
                SizedBox(height: 10),
                Text("Used: ₹$usedAmount  |  Not Used: ₹$remaining",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: remaining < 0 ? Colors.red : Colors.green)),
              ],
            ),
          ),

          // 2. Middle Section: Pending Invoices List
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
                          // Format Bill Date
                          String bDate = DateFormat('dd-MM-yyyy')
                              .format(DateTime.parse(bill['date']));
                          return Card(
                            color:
                                isSelected ? Colors.green[100] : Colors.white,
                            margin: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: Checkbox(
                                value: isSelected,
                                onChanged: (val) => _allocateAmount(
                                    bill['id'], bill['pending_amount']),
                              ),
                              title: Text("Bill Date: $bDate"),
                              subtitle: Text(
                                  "Total: ₹${bill['amount']} | Pending: ₹${bill['pending_amount']}"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Allocated",
                                      style: TextStyle(fontSize: 10)),
                                  Text(
                                      isSelected
                                          ? "₹${_allocations[bill['id']]}"
                                          : "-",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // 3. Bottom Section: Save Button
          Padding(
            padding: EdgeInsets.all(15),
            child: ElevatedButton(
              onPressed: _savePayment,
              child: Text("SAVE TRANSACTION"),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50)),
            ),
          )
        ],
      ),
    );
  }
}
