import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

class OutstandingPage extends StatefulWidget {
  @override
  _OutstandingPageState createState() => _OutstandingPageState();
}

class _OutstandingPageState extends State<OutstandingPage> {
  List<Map<String, dynamic>> _outstandingList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOutstanding();
  }

  void _fetchOutstanding() async {
    // 1. Get all uncleared bills
    List<Map<String, dynamic>> bills =
        await DatabaseHelper.instance.getAllUnclearedBills();

    // 2. Group by Party
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var bill in bills) {
      if (!grouped.containsKey(bill['party'])) {
        grouped[bill['party']] = [];
      }
      grouped[bill['party']]!.add(bill);
    }

    // 3. Process each party to find "Criticality"
    List<Map<String, dynamic>> processedList = [];
    DateTime today = DateTime.now();

    grouped.forEach((party, partyBills) {
      double totalPending = 0.0;
      int maxOverdueDays =
          -9999; // Represents the "worst" bill status for this party

      for (var bill in partyBills) {
        totalPending += bill['pending_amount'];

        DateTime billDate = DateTime.parse(bill['date']);
        int creditDays = bill['credit_period'] ?? 0;
        DateTime dueDate = billDate.add(Duration(days: creditDays));

        // Positive = Overdue, Negative = Due in Future
        int overdueBy = today.difference(dueDate).inDays;

        // We want to find the bill that is MOST overdue (highest positive number)
        // OR the one closest to being due (highest negative number closer to 0)
        if (overdueBy > maxOverdueDays) {
          maxOverdueDays = overdueBy;
        }
      }

      // Determine Color Category
      // Red: Overdue > 0 days
      // Yellow: Due within 7 days (overdueBy between -7 and 0)
      // Green: Safe
      int colorCode = 0; // 0=Green, 1=Yellow, 2=Red
      if (maxOverdueDays > 0) {
        colorCode = 2;
      } else if (maxOverdueDays >= -7) {
        colorCode = 1;
      }

      processedList.add({
        'party': party,
        'total': totalPending,
        'max_overdue': maxOverdueDays,
        'color_code': colorCode
      });
    });

    // 4. Sort: Red (2) -> Yellow (1) -> Green (0), then by amount desc
    processedList.sort((a, b) {
      int colorComp =
          b['color_code'].compareTo(a['color_code']); // Descending color
      if (colorComp != 0) return colorComp;
      return b['max_overdue']
          .compareTo(a['max_overdue']); // Most overdue first within color
    });

    setState(() {
      _outstandingList = processedList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Outstanding Dues")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _outstandingList.isEmpty
              ? Center(child: Text("No outstanding dues! Great job!"))
              : ListView.builder(
                  itemCount: _outstandingList.length,
                  itemBuilder: (context, index) {
                    final item = _outstandingList[index];

                    Color bgColor;
                    Color textColor = Colors.black;
                    String status = "";

                    if (item['color_code'] == 2) {
                      bgColor = Colors.red[100]!;
                      status = "OVERDUE (${item['max_overdue']} days)";
                      textColor = Colors.red[900]!;
                    } else if (item['color_code'] == 1) {
                      bgColor = Colors.yellow[100]!;
                      // Show exact days remaining (abs value of negative overdue days)
                      int daysLeft = (item['max_overdue'] as int).abs();
                      status = "DUE IN $daysLeft DAYS";
                      textColor = Colors.orange[900]!;
                    } else {
                      bgColor = Colors.green[50]!;
                      status = "Safe";
                      textColor = Colors.green[900]!;
                    }

                    return Card(
                      color: bgColor,
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        onTap: () {
                          // Open Ledger for this party
                          Navigator.pushNamed(context, '/ledger',
                              arguments: item['party']);
                        },
                        title: Text(item['party'],
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text(status,
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.bold)),
                        trailing: Text("₹${item['total'].toStringAsFixed(2)}",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}
