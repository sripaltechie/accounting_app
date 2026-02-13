import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Account Ledger")),
      body: GridView.count(
        padding: EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
        children: [
          _buildMenuButton(context, "Purchase Bill", Icons.shopping_cart,
              Colors.green, '/transaction'),
          _buildMenuButton(
              context, "Sales Bill", Icons.sell, Colors.blue, '/transaction'),

          _buildActionCard(
              context, "Receipt (In)", Icons.download, Colors.teal, 'Receipt'),
          _buildActionCard(context, "Payment (Out)", Icons.upload,
              Colors.redAccent, 'Payment'),

          _buildMenuButton(context, "Full Ledger", Icons.bar_chart,
              Colors.deepPurple, '/ledger'),
          _buildMenuButton(context, "Parties", Icons.people, Colors.indigo,
              '/parties'), // New Button

          _buildMenuButton(context, "Outstanding", Icons.warning, Colors.orange,
              '/outstanding'), // New Button
          _buildMenuButton(
              context, "Daybook", Icons.menu_book, Colors.purple, '/daybook'),

          _buildMenuButton(context, "Payment Modes", Icons.payment,
              Colors.blueGrey, '/payment_modes'), // New Button
          _buildMenuButton(
              context, "Backup", Icons.backup, Colors.grey, '/backup'),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon,
      Color color, String route) {
    return InkWell(
      onTap: () {
        if (title.contains("Purchase"))
          Navigator.pushNamed(context, route, arguments: "Purchase");
        else if (title.contains("Sales"))
          Navigator.pushNamed(context, route, arguments: "Sales");
        else
          Navigator.pushNamed(context, route);
      },
      child: Card(
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon,
      Color color, String arg) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/payment', arguments: arg),
      child: Card(
        color: color.withOpacity(0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
