import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Accounting Ledger - Dashboard")),
      body: GridView.count(
        padding: EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildMenuButton(
              context, "Purchase", Icons.shopping_cart, Colors.green),
          _buildMenuButton(context, "Sales", Icons.sell, Colors.blue),
          _buildMenuButton(
              context, "Receipt (In)", Icons.download, Colors.blue),
          _buildMenuButton(context, "Payment (Out)", Icons.upload, Colors.blue),
          _buildMenuButton(
              context, "Ledger", Icons.account_balance_wallet, Colors.orange),
          _buildMenuButton(context, "Daybook", Icons.menu_book, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, String title, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        // We pass the type (Purchase/Sale) to the transaction page
        if (title == "Purchase" || title == "Sales") {
          Navigator.pushNamed(context, '/transaction', arguments: title);
        } else if (title == "Receipt (In)" || title == "Payment (Out)") {
          Navigator.pushNamed(context, '/payment', arguments: title);
        } else if (title == "Ledger") {
          Navigator.pushNamed(context, '/balances', arguments: title);
        } else if (title == "Daybook") {
          Navigator.pushNamed(context, '/daybook', arguments: title);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$title feature coming soon!")));
        }
      },
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: color)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
