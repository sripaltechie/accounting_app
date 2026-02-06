// import 'package:flutter/material.dart';
// import 'database_helper.dart';

// class BalancePage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Pending Collections")),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: DatabaseHelper.instance.getPendingBalances(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData)
//             return Center(child: CircularProgressIndicator());
//           if (snapshot.data!.isEmpty)
//             return Center(child: Text("All accounts cleared!"));

//           return ListView.builder(
//             itemCount: snapshot.data!.length,
//             itemBuilder: (context, index) {
//               final item = snapshot.data![index];
//               return Card(
//                 margin: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
//                 child: ListTile(
//                   title: Text(item['party'],
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Text("Pending since: ${item['oldest_bill']}"),
//                   trailing: Text("₹${item['balance']}",
//                       style: TextStyle(
//                           color: Colors.red,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 18)),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
