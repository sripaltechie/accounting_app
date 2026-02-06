import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LedgerPage extends StatefulWidget {
  @override
  _LedgerPageState createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _partyController = TextEditingController();
  DateTime _fromDate = DateTime.now().subtract(Duration(days: 365));
  DateTime _toDate = DateTime.now();

  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _payments = [];
  String? _mobileNumber;

  bool _isLoading = false;
  bool _hasSearched = false;
  bool _initDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initDone) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _partyController.text = args;
        _fetchLedger();
      }
      _initDone = true;
    }
  }

  String get _fromStr => DateFormat('yyyy-MM-dd').format(_fromDate);
  String get _toStr => DateFormat('yyyy-MM-dd').format(_toDate);
  String _displayDate(String iso) =>
      DateFormat('dd-MM-yyyy').format(DateTime.parse(iso));

  Future<void> _pickDate(bool isFrom) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom)
          _fromDate = picked;
        else
          _toDate = picked;
      });
    }
  }

  Future<void> _fetchLedger() async {
    if (_partyController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    var bills = await DatabaseHelper.instance
        .getLedgerBills(_partyController.text, _fromStr, _toStr);
    var payments = await DatabaseHelper.instance
        .getLedgerPayments(_partyController.text, _fromStr, _toStr);
    var partyData = await DatabaseHelper.instance
        .getPartyByName(_partyController.text.trim());

    setState(() {
      _bills = bills;
      _payments = payments;
      _mobileNumber = partyData?['mobile'];
      _isLoading = false;
    });
  }

  // --- PDF GENERATION & SHARE ---
  Future<void> _generateAndSharePdf() async {
    if (_bills.isEmpty && _payments.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No data to generate PDF")));
      return;
    }

    final pdf = pw.Document();

    // Calculate Totals
    double totalBills =
        _bills.fold(0, (sum, item) => sum + (item['amount'] as num));
    double totalReceived =
        _payments.fold(0, (sum, item) => sum + (item['amount'] as num));
    double netOutstanding = totalBills - totalReceived;

    // Define Fonts/Styles
    final titleStyle =
        pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
    final headerStyle =
        pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final regularStyle = pw.TextStyle(fontSize: 12);

    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Hithvi Ledger", style: titleStyle),
                        pw.Text("Ledger Statement", style: headerStyle),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Party: ${_partyController.text}",
                            style: headerStyle),
                        pw.Text(
                            "From: ${_displayDate(_fromStr)} To: ${_displayDate(_toStr)}",
                            style: regularStyle),
                        if (_mobileNumber != null)
                          pw.Text("Mobile: $_mobileNumber",
                              style: regularStyle),
                      ])
                ]),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(children: [
                        pw.Text("Total Billed"),
                        pw.Text("Rs. ${totalBills.toStringAsFixed(2)}",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                      ]),
                      pw.Column(children: [
                        pw.Text("Total Received"),
                        pw.Text("Rs. ${totalReceived.toStringAsFixed(2)}",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                      ]),
                      pw.Column(children: [
                        pw.Text("Net Outstanding"),
                        pw.Text("Rs. ${netOutstanding.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red))
                      ]),
                    ])),
            pw.SizedBox(height: 20),

            // Bills Table
            pw.Text("Invoices / Bills", style: headerStyle),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Bill ID', 'Notes', 'Amount', 'Status'],
              data: _bills
                  .map((item) => [
                        _displayDate(item['date']),
                        item['id'].toString(),
                        item['notes'] ?? '',
                        item['amount'].toString(),
                        item['cleared'] == 1 ? "Cleared" : "Pending"
                      ])
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 20),

            // Payments Table
            pw.Text("Payments & Receipts", style: headerStyle),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Type', 'Mode', 'Notes', 'Amount'],
              data: _payments
                  .map((item) => [
                        _displayDate(item['date']),
                        item['type'],
                        item['payment_mode'] ?? 'Cash',
                        item['notes'] ?? '',
                        item['amount'].toString(),
                      ])
                  .toList(),
              border: pw.TableBorder.all(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Center(
                child: pw.Text("Generated by Hithvi Ledger App",
                    style: pw.TextStyle(color: PdfColors.grey)))
          ];
        }));

    // Save File
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Ledger_${_partyController.text}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Share File
    // Note: Standard WhatsApp API does not allow attaching a file to a specific number programmatically.
    // The best practice is to open the Share Sheet. The user selects WhatsApp -> Contact.
    await Share.shareXFiles([XFile(file.path)],
        text:
            "Hello ${_partyController.text}, please find the attached ledger statement. Net Outstanding: Rs. ${netOutstanding.toStringAsFixed(2)}");
  }

  // --- WHATSAPP TEXT LAUNCHER ---
  void _launchWhatsApp() async {
    if (_mobileNumber == null || _mobileNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No mobile number found for this party.")));
      return;
    }

    double totalBills =
        _bills.fold(0, (sum, item) => sum + (item['amount'] as num));
    double totalReceived =
        _payments.fold(0, (sum, item) => sum + (item['amount'] as num));
    double netOutstanding = totalBills - totalReceived;

    DateTime today = DateTime.now();
    int maxOverdueDays = -9999;

    for (var bill in _bills) {
      if (bill['cleared'] == 0) {
        DateTime billDate = DateTime.parse(bill['date']);
        int creditDays = bill['credit_period'] ?? 0;
        DateTime dueDate = billDate.add(Duration(days: creditDays));
        int diff = today.difference(dueDate).inDays;
        if (diff > maxOverdueDays) maxOverdueDays = diff;
      }
    }

    String statusMsg = "";
    if (maxOverdueDays > 0) {
      statusMsg = "Your bill is OVERDUE by $maxOverdueDays days.";
    } else if (maxOverdueDays >= -7 && maxOverdueDays != -9999) {
      statusMsg = "Your bill is due in ${maxOverdueDays.abs()} days.";
    }

    String message =
        "Hello ${_partyController.text}, your total outstanding balance with Hithvi Creations is Rs. ${netOutstanding.toStringAsFixed(2)}. $statusMsg Please pay at the earliest.";

    final Uri url = Uri.parse(
        "https://wa.me/+91$_mobileNumber?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Could not launch WhatsApp")));
    }
  }

  void _editTransaction(Map<String, dynamic> trans) {
    String route = (trans['type'] == 'Purchase' || trans['type'] == 'Sales')
        ? '/transaction'
        : '/payment';
    Navigator.pushNamed(context, route,
            arguments: {'type': trans['type'], 'data': trans})
        .then((_) => _fetchLedger());
  }

  void _deleteTransaction(int id, String type) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: Text("Delete Transaction?"),
                  content: Text(
                      "This will remove the entry and any links. Continue?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text("No")),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child:
                            Text("Yes", style: TextStyle(color: Colors.red))),
                  ],
                )) ??
        false;

    if (confirm) {
      await DatabaseHelper.instance.deleteTransaction(id);
      _fetchLedger();
    }
  }

  void _showLinkPopup(
      int paymentId, double unallocatedAmount, String type) async {
    List<Map<String, dynamic>> pendingBills = await DatabaseHelper.instance
        .getPendingInvoices(_partyController.text, type);
    Map<int, double> allocations = {};
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            double currentlyAllocated =
                allocations.values.fold(0.0, (sum, val) => sum + val);
            double remaining = unallocatedAmount - currentlyAllocated;
            return AlertDialog(
              title: Text("Link Payment (Available: ₹$unallocatedAmount)"),
              content: Container(
                width: double.maxFinite,
                child: pendingBills.isEmpty
                    ? Text("No pending bills found for this party.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: pendingBills.length,
                        itemBuilder: (context, index) {
                          var bill = pendingBills[index];
                          bool isSelected = allocations.containsKey(bill['id']);
                          return CheckboxListTile(
                            title: Text(
                                "${_displayDate(bill['date'])} - Total: ₹${bill['amount']}"),
                            subtitle: Text(
                                "Pending: ₹${bill['pending_amount']}",
                                style: TextStyle(color: Colors.red)),
                            value: isSelected,
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  double amountToAlloc =
                                      (remaining >= bill['pending_amount'])
                                          ? bill['pending_amount']
                                          : remaining;
                                  if (amountToAlloc > 0)
                                    allocations[bill['id']] = amountToAlloc;
                                } else {
                                  allocations.remove(bill['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel")),
                ElevatedButton(
                    onPressed: allocations.isEmpty
                        ? null
                        : () async {
                            List<Map<String, dynamic>> allocList = [];
                            allocations.forEach((k, v) =>
                                allocList.add({'invoice_id': k, 'amount': v}));
                            await DatabaseHelper.instance.linkExistingPayment(
                                paymentId, unallocatedAmount, allocList);
                            Navigator.pop(context);
                            _fetchLedger();
                          },
                    child: Text("Link Selected"))
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    double totalBills =
        _bills.fold(0, (sum, item) => sum + (item['amount'] as num));
    double totalReceived =
        _payments.fold(0, (sum, item) => sum + (item['amount'] as num));
    double netOutstanding = totalBills - totalReceived;

    return Scaffold(
      appBar: AppBar(
        title: Text("Ledger Report"),
        actions: [
          // PDF Share Button
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            tooltip: "Share PDF",
            onPressed: _generateAndSharePdf,
          ),
          // WhatsApp Text Button
          if (_mobileNumber != null && _mobileNumber!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: Icon(Icons.message, color: Colors.greenAccent),
                tooltip: "WhatsApp Text",
                onPressed: _launchWhatsApp,
              ),
            )
        ],
      ),
      body: Column(
        children: [
          ExpansionTile(
            title: Text("Filters"),
            initiallyExpanded: !_hasSearched,
            children: [
              Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  children: [
                    Autocomplete<String>(
                      optionsBuilder: (val) async => val.text == ''
                          ? []
                          : await DatabaseHelper.instance
                              .getMatchingParties(val.text),
                      onSelected: (val) => _partyController.text = val,
                      fieldViewBuilder: (ctx, controller, focus, onSub) {
                        return TextField(
                            controller: controller,
                            focusNode: focus,
                            decoration: InputDecoration(
                                labelText: "Party Name",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person)));
                      },
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => _pickDate(true),
                                child:
                                    Text("From: ${_displayDate(_fromStr)}"))),
                        SizedBox(width: 10),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => _pickDate(false),
                                child: Text("To: ${_displayDate(_toStr)}"))),
                      ],
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: _fetchLedger,
                        child: Text("GENERATE REPORT"),
                        style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 45))),
                  ],
                ),
              )
            ],
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? SizedBox()
                    : ListView(
                        padding: EdgeInsets.all(15),
                        children: [
                          Text("Invoices / Bills",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Divider(),
                          ..._bills.map((bill) {
                            return Card(
                              child: ListTile(
                                onLongPress: () => _deleteTransaction(
                                    bill['id'], bill['type']),
                                onTap: () => _editTransaction(bill),
                                title:
                                    Text("Date: ${_displayDate(bill['date'])}"),
                                subtitle: Text(
                                    "Bill #${bill['id']} - ${bill['notes'] ?? ''}"),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("₹${bill['amount']}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        bill['cleared'] == 1
                                            ? "CLEARED"
                                            : "PENDING",
                                        style: TextStyle(
                                            color: bill['cleared'] == 1
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          SizedBox(height: 20),
                          Text("Receipts & Payments",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Divider(),
                          ..._payments.map((pay) {
                            double unallocated =
                                (pay['unallocated_amount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                            return Card(
                              color: Colors.grey[100],
                              child: ListTile(
                                onLongPress: () =>
                                    _deleteTransaction(pay['id'], pay['type']),
                                onTap: () => _editTransaction(pay),
                                title: Text(
                                    "${pay['type']} - ${_displayDate(pay['date'])}"),
                                subtitle: Text(
                                    "Mode: ${pay['payment_mode'] ?? 'Cash'}"),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("₹${pay['amount']}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    if (unallocated > 0)
                                      InkWell(
                                        onTap: () => _showLinkPopup(pay['id'],
                                            unallocated, pay['type']),
                                        child: Text("LINK",
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold)),
                                      )
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          SizedBox(height: 30),
                          Container(
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                                color: Colors.indigo[50],
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              children: [
                                Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Total Invoiced"),
                                          Text(
                                              "₹${totalBills.toStringAsFixed(2)}")
                                        ])),
                                Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Total Received/Paid"),
                                          Text(
                                              "₹${totalReceived.toStringAsFixed(2)}")
                                        ])),
                                Divider(),
                                Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Net Outstanding",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(
                                              "₹${netOutstanding.toStringAsFixed(2)}",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16))
                                        ])),
                              ],
                            ),
                          )
                        ],
                      ),
          )
        ],
      ),
    );
  }
}
