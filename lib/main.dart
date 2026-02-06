import 'package:accouting_app/balance_page.dart';
import 'package:accouting_app/daybook_page.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'dashboard.dart';
import 'payment_page.dart';
import 'transaction_page.dart';
import 'package:workmanager/workmanager.dart';
import 'database_helper.dart';
import 'dart:io';

const autoBackupTask = "com.accounting.autoBackup";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await DatabaseHelper.instance.performBackup();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Workmanager
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Schedule the 7 AM backup
  _scheduleDailyBackup();

  runApp(AccountingApp());
}

void _scheduleDailyBackup() {
  final now = DateTime.now();
  var firstTime = DateTime(now.year, now.month, now.day, 7, 0); // 7:00 AM

  if (firstTime.isBefore(now)) {
    firstTime = firstTime.add(const Duration(days: 1));
  }

  final initialDelay = firstTime.difference(now);

  Workmanager().registerPeriodicTask(
    "1",
    autoBackupTask,
    frequency: const Duration(hours: 24),
    initialDelay: initialDelay,
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresStorageNotLow: true,
    ),
  );
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accounting Ledger',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      // Update your routes in main.dart
      routes: {
        '/': (context) => LoginPage(),
        '/dashboard': (context) => Dashboard(),
        '/transaction': (context) => TransactionPage(),
        '/payment': (context) => PaymentPage(),
        '/daybook': (context) => DaybookPage(),
        '/balances': (context) => BalancePage(),
      },
    );
  }
}
