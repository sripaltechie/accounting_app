import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:intl/intl.dart';

class DaybookPage extends StatefulWidget {
  @override
  _DaybookPageState createState() => _DaybookPageState();
}

class _DaybookPageState extends State<DaybookPage> {
  // Default to today
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String displayDate = DateFormat('dd-MM-yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text("Daybook"),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month),
            onPressed: _pickDate,
            tooltip: "Filter Date",
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Date: $displayDate",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(onPressed: _pickDate, child: Text("CHANGE"))
              ],
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getDaybook(formattedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text("No transactions found on this date."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    Color typeColor = Colors.grey;
                    IconData icon = Icons.info;

                    if (item['type'] == 'Sales') {
                      typeColor = Colors.blue;
                      icon = Icons.sell;
                    } else if (item['type'] == 'Purchase') {
                      typeColor = Colors.green;
                      icon = Icons.shopping_cart;
                    } else if (item['type'] == 'Receipt') {
                      typeColor = Colors.teal;
                      icon = Icons.download;
                    } else if (item['type'] == 'Payment') {
                      typeColor = Colors.red;
                      icon = Icons.upload;
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: typeColor.withOpacity(0.2),
                        child: Icon(icon, color: typeColor, size: 20),
                      ),
                      title: Text(item['party'],
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          Text("${item['type']} • ${item['notes'] ?? ''}"),
                      trailing: Text("₹${item['amount']}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
