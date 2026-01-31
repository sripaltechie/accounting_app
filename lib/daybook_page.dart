import 'package:flutter/material.dart';
import 'database_helper.dart';

class DaybookPage extends StatelessWidget {
  final String today = DateTime.now().toString().split(' ')[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Daybook ($today)")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getDaybook(today),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty)
            return Center(child: Text("No transactions today"));

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final item = snapshot.data![index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      item['type'] == 'Sales' ? Colors.blue : Colors.green,
                  child: Text(item['type'][0]),
                ),
                title: Text(item['party']),
                subtitle: Text(item['notes']),
                trailing: Text("₹${item['amount']}",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          );
        },
      ),
    );
  }
}
