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
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
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
        '/license': (context) => AppActivationPage(),
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
