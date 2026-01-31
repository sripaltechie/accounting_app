import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        party TEXT,
        amount REAL,
        notes TEXT,
        date TEXT,
        credit_period INTEGER,       -- New: For Reminders
        cleared INTEGER DEFAULT 0, -- New: 1 if bill is fully paid
        unallocated_amount REAL -- New: For Payments/Receipts
      )
    ''');

    // Allocation Table: Links Payments to Invoices
    await db.execute('''
      CREATE TABLE allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_id INTEGER,
        invoice_id INTEGER,
        amount REAL,
        FOREIGN KEY(payment_id) REFERENCES transactions(id),
        FOREIGN KEY(invoice_id) REFERENCES transactions(id)
      )
    ''');

    await db
        .execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.insert('settings', {'key': 'pin', 'value': '1234'});
  }

  // --- TYPEAHEAD HELPER ---
  Future<List<String>> getMatchingParties(String query) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
        'SELECT DISTINCT party FROM transactions WHERE party LIKE ? LIMIT 10',
        ['%$query%']);
    return List.generate(maps.length, (i) => maps[i]['party'] as String);
  }

  Future<String> getPin() async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = "pin"');
    return res.isNotEmpty ? res.first['value'] as String : '1234';
  }

  Future updatePin(String newPin) async {
    final db = await instance.database;
    await db.update('settings', {'value': newPin}, where: 'key = "pin"');
  }

  // For Daybook: Fetch all transactions for a specific date
  Future<List<Map<String, dynamic>>> getDaybook(String date) async {
    final db = await instance.database;
    return await db.query('transactions', where: 'date = ?', whereArgs: [date]);
  }

  // For Pending Balance: Get parties with a calculated balance
// Note: In simple accounting, we group by Party and find (Sales - Receipts)
  Future<List<Map<String, dynamic>>> getPendingBalances() async {
    final db = await instance.database;
    // This query calculates total Sales minus total Receipts/Payments per party
    // We sort by the MIN(id) to find who has the oldest outstanding bill
    return await db.rawQuery('''
    SELECT party, 
    SUM(CASE WHEN type = 'Sales' THEN amount ELSE -amount END) as balance,
    MIN(date) as oldest_bill
    FROM transactions 
    GROUP BY party 
    HAVING balance > 0 
    ORDER BY oldest_bill ASC
  ''');
  }

  // --- NEW LOGIC FOR LINKING ---

  // 1. Get Pending Bills for a Party (Only uncleared Purchase/Sale)
  Future<List<Map<String, dynamic>>> getPendingInvoices(
      String party, String type) async {
    final db = await instance.database;
    // If we are making a "Payment", we look for "Purchase" bills.
    // If we are making a "Receipt", we look for "Sale" bills.
    String targetType = (type == 'Payment') ? 'Purchase' : 'Sales';

    // Get bills that are NOT cleared
    final List<Map<String, dynamic>> bills = await db.query(
      'transactions',
      where: 'party = ? AND type = ? AND cleared = 0',
      whereArgs: [party, targetType],
      orderBy: 'date ASC', // Oldest first
    );

    // We need to calculate how much is already paid for each bill
    List<Map<String, dynamic>> result = [];
    for (var bill in bills) {
      var paidResult = await db.rawQuery(
          'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
          [bill['id']]);
      double paid = (paidResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double pending = (bill['amount'] as num).toDouble() - paid;

      if (pending > 0) {
        result.add({...bill, 'pending_amount': pending});
      }
    }
    return result;
  }

  // 2. Save Payment with Links
  Future<void> createPaymentWithAllocations(Map<String, dynamic> paymentData,
      List<Map<String, dynamic>> allocations) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // A. Insert the Payment/Receipt Record
      int paymentId = await txn.insert('transactions', paymentData);

      // B. Insert Allocations and Check if Invoices are Cleared
      for (var alloc in allocations) {
        await txn.insert('allocations', {
          'payment_id': paymentId,
          'invoice_id': alloc['invoice_id'],
          'amount': alloc['amount']
        });

        // Check if this invoice is now fully paid
        int invoiceId = alloc['invoice_id'];
        var invRes = await txn
            .query('transactions', where: 'id = ?', whereArgs: [invoiceId]);
        double invTotal = (invRes.first['amount'] as num).toDouble();

        var paidRes = await txn.rawQuery(
            'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
            [invoiceId]);
        // Note: We must use the txn here so it sees the insert we just made
        double totalPaid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;

        // Tolerance for float math
        if (totalPaid >= (invTotal - 0.1)) {
          await txn.update('transactions', {'cleared': 1},
              where: 'id = ?', whereArgs: [invoiceId]);
        }
      }
    });
  }

  // --- UPDATED INSERT FOR REGULAR BILLS ---
  Future insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Ensure new fields are handled defaults
    if (!row.containsKey('cleared')) row['cleared'] = 0;
    return await db.insert('transactions', row);
  }

  Future<String> performBackup() async {
    final dbPath = await getDatabasesPath();
    final sourcePath = join(dbPath, 'ledger.db');

    // Choose a location (Downloads or Documents)
    Directory? externalDir = await getExternalStorageDirectory();
    String backupPath = join(externalDir!.path,
        "Accouting_Backup_${DateTime.now().millisecondsSinceEpoch}.db");

    File sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(backupPath);
      return backupPath;
    }
    return "Source file not found";
  }

  Future<bool> restoreBackup(String backupPath) async {
    final dbPath = await getDatabasesPath();
    final destinationPath = join(dbPath, 'ledger.db');

    File backupFile = File(backupPath);
    if (await backupFile.exists()) {
      // Close DB before overwriting
      final db = await instance.database;
      await db.close();

      await backupFile.copy(destinationPath);
      // Force re-initialization of DB link next time it's accessed
      _database = null;
      return true;
    }
    return false;
  }
}
