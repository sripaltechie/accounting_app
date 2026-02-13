import 'package:accouting_app/license_page.dart';
import 'package:accouting_app/paymentmode_page.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'database_helper.dart';
import 'dart:io';

import 'login_page.dart';
import 'dashboard.dart';
import 'transaction_page.dart';
import 'daybook_page.dart';
import 'backup_page.dart';
import 'payment_page.dart';
import 'ledger_page.dart';
import 'party_page.dart'; // New Import
import 'outstanding_page.dart'; // New Import
import 'license_page.dart';

const autoBackupTask = "com.hithvi.autoBackup";

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
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    // 2. SCHEDULE THE TASK (This was missing)
    // This tells Android to run the backup roughly every 24 hours
    await Workmanager().registerPeriodicTask(
      "1", // Unique ID for this task
      autoBackupTask, // Task name defined above
      frequency: const Duration(hours: 24), // How often to run
      // constraints: Constraints(
      //   // Only run if device is charging (optional, good for battery)
      //   requiresBatteryNotLow: true,
      //   networkType: NetworkType.not_required
      // ),
      existingWorkPolicy: ExistingWorkPolicy.keep, // Don't schedule duplicates
    );
  }
  runApp(HithviLedgerApp());
}

class HithviLedgerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Account Ledger',
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: false),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/license': (context) => ActivationPage(),
        '/dashboard': (context) => Dashboard(),
        '/transaction': (context) => TransactionPage(),
        '/daybook': (context) => DaybookPage(),
        '/backup': (context) => BackupPage(),
        '/payment': (context) => PaymentPage(),
        '/ledger': (context) => LedgerPage(),
        '/payment_modes': (context) => PaymentModePage(),
        '/parties': (context) => PartyPage(), // New Route
        '/outstanding': (context) => OutstandingPage(), // New Route
      },
    );
  }
}
