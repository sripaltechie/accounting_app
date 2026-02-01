import 'dart:io';

import 'package:intl/intl.dart';
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
    // Version 1 for testing - clear app data to reset schema
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        party TEXT,
        amount REAL,
        notes TEXT,
        date TEXT,
        credit_period INTEGER,
        cleared INTEGER DEFAULT 0,
        unallocated_amount REAL,
        payment_mode TEXT
      )
    ''');

    // 2. Allocations
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

    // 3. Payment Modes
    await db.execute(
        'CREATE TABLE payment_modes (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)');
    await db.insert('payment_modes', {'name': 'Cash'});

    // 4. Parties (NEW)
    await db.execute('''
      CREATE TABLE parties (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT UNIQUE, 
        mobile TEXT
      )
    ''');

    // 5. Settings
    await db
        .execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.insert('settings', {'key': 'pin', 'value': '1234'});
  }

  // --- PARTY MANAGEMENT ---
  Future<int> insertParty(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('parties', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllParties() async {
    final db = await instance.database;
    return await db.query('parties', orderBy: 'name ASC');
  }

  Future<int> updateParty(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db
        .update('parties', row, where: 'id = ?', whereArgs: [row['id']]);
  }

  Future<int> deleteParty(int id) async {
    final db = await instance.database;
    return await db.delete('parties', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getPartyByName(String name) async {
    final db = await instance.database;
    final res = await db.query('parties',
        where: 'name = ?', whereArgs: [name], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  // Updated Typeahead to look at Parties table first, then fallback to transactions
  Future<List<String>> getMatchingParties(String query) async {
    final db = await instance.database;
    // 1. Try Parties Table
    final List<Map<String, dynamic>> partyMaps = await db.query('parties',
        columns: ['name'],
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        limit: 10);

    if (partyMaps.isNotEmpty) {
      return List.generate(
          partyMaps.length, (i) => partyMaps[i]['name'] as String);
    }

    // 2. Fallback to existing transactions (Legacy support)
    final List<Map<String, dynamic>> transMaps = await db.rawQuery(
        'SELECT DISTINCT party FROM transactions WHERE party LIKE ? LIMIT 10',
        ['%$query%']);
    return List.generate(
        transMaps.length, (i) => transMaps[i]['party'] as String);
  }

  // --- TRANSACTION CRUD ---
  Future<int> updateTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db
        .update('transactions', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    // Note: In a real app, you should delete allocations linked to this transaction too.
    await db.delete('allocations',
        where: 'payment_id = ? OR invoice_id = ?', whereArgs: [id, id]);
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // --- REPORTING HELPERS ---

  // Get all uncleared bills for Outstanding Report
  Future<List<Map<String, dynamic>>> getAllUnclearedBills() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> bills = await db.rawQuery('''
      SELECT * FROM transactions 
      WHERE (type = 'Purchase' OR type = 'Sales') AND cleared = 0
    ''');

    List<Map<String, dynamic>> result = [];
    for (var bill in bills) {
      var paidRes = await db.rawQuery(
          'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
          [bill['id']]);
      double paid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
      double pending = (bill['amount'] as num).toDouble() - paid;

      if (pending > 0.1) {
        // Tolerance
        result.add({...bill, 'pending_amount': pending});
      }
    }
    return result;
  }

  // --- EXISTING HELPERS (Keep as is) ---
  Future<String> getPin() async {
    final db = await instance.database;
    final res = await db.query('settings', where: 'key = "pin"');
    return res.isNotEmpty ? res.first['value'] as String : '1234';
  }

  Future updatePin(String newPin) async {
    final db = await instance.database;
    await db.update('settings', {'value': newPin}, where: 'key = "pin"');
  }

  Future<List<Map<String, dynamic>>> getPendingInvoices(
      String party, String type) async {
    final db = await instance.database;
    String targetType = (type == 'Payment') ? 'Purchase' : 'Sales';
    final List<Map<String, dynamic>> bills = await db.query(
      'transactions',
      where: 'party = ? COLLATE NOCASE AND type = ? AND cleared = 0',
      whereArgs: [party.trim(), targetType],
      orderBy: 'date ASC',
    );
    List<Map<String, dynamic>> result = [];
    for (var bill in bills) {
      var paidResult = await db.rawQuery(
          'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
          [bill['id']]);
      double paid = (paidResult.first['total'] as num?)?.toDouble() ?? 0.0;
      double pending = (bill['amount'] as num).toDouble() - paid;
      if (pending > 0) result.add({...bill, 'pending_amount': pending});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getLedgerBills(
      String party, String fromDate, String toDate) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> bills = await db.rawQuery('''
      SELECT * FROM transactions 
      WHERE party = ? COLLATE NOCASE AND (type = 'Purchase' OR type = 'Sales') 
      AND date BETWEEN ? AND ?
      ORDER BY date ASC
    ''', [party.trim(), fromDate, toDate]);
    List<Map<String, dynamic>> result = [];
    for (var bill in bills) {
      var paidRes = await db.rawQuery(
          'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
          [bill['id']]);
      double paid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
      result.add({...bill, 'paid_amount': paid});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getLedgerPayments(
      String party, String fromDate, String toDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT * FROM transactions 
      WHERE party = ? COLLATE NOCASE AND (type = 'Payment' OR type = 'Receipt') 
      AND date BETWEEN ? AND ?
      ORDER BY date ASC
    ''', [party.trim(), fromDate, toDate]);
  }

  Future<void> createPaymentWithAllocations(Map<String, dynamic> paymentData,
      List<Map<String, dynamic>> allocations) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      int paymentId = await txn.insert('transactions', paymentData);
      for (var alloc in allocations) {
        await txn.insert('allocations', {
          'payment_id': paymentId,
          'invoice_id': alloc['invoice_id'],
          'amount': alloc['amount']
        });
        int invoiceId = alloc['invoice_id'];
        var invRes = await txn
            .query('transactions', where: 'id = ?', whereArgs: [invoiceId]);
        double invTotal = (invRes.first['amount'] as num).toDouble();
        var paidRes = await txn.rawQuery(
            'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
            [invoiceId]);
        double totalPaid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
        if (totalPaid >= (invTotal - 0.1))
          await txn.update('transactions', {'cleared': 1},
              where: 'id = ?', whereArgs: [invoiceId]);
      }
    });
  }

  Future insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    if (!row.containsKey('cleared')) row['cleared'] = 0;
    return await db.insert('transactions', row);
  }

  Future linkExistingPayment(int paymentId, double originalUnallocated,
      List<Map<String, dynamic>> newAllocations) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      double allocatedNow = 0.0;
      for (var alloc in newAllocations) {
        double amount = alloc['amount'];
        allocatedNow += amount;
        await txn.insert('allocations', {
          'payment_id': paymentId,
          'invoice_id': alloc['invoice_id'],
          'amount': amount
        });
        int invoiceId = alloc['invoice_id'];
        var invRes = await txn
            .query('transactions', where: 'id = ?', whereArgs: [invoiceId]);
        double invTotal = (invRes.first['amount'] as num).toDouble();
        var paidRes = await txn.rawQuery(
            'SELECT SUM(amount) as total FROM allocations WHERE invoice_id = ?',
            [invoiceId]);
        double totalPaid = (paidRes.first['total'] as num?)?.toDouble() ?? 0.0;
        if (totalPaid >= (invTotal - 0.1)) {
          await txn.update('transactions', {'cleared': 1},
              where: 'id = ?', whereArgs: [invoiceId]);
        }
      }
      double newUnallocated = originalUnallocated - allocatedNow;
      await txn.update('transactions', {'unallocated_amount': newUnallocated},
          where: 'id = ?', whereArgs: [paymentId]);
    });
  }

  Future<List<String>> getPaymentModes() async {
    final db = await instance.database;
    final res = await db.query('payment_modes', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<int> addPaymentMode(String name) async {
    final db = await instance.database;
    return await db.insert('payment_modes', {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deletePaymentMode(String name) async {
    final db = await instance.database;
    if (name == 'Cash') return 0;
    return await db
        .delete('payment_modes', where: 'name = ?', whereArgs: [name]);
  }

  Future<List<Map<String, dynamic>>> getDaybook(String date) async {
    final db = await instance.database;
    return await db.query('transactions', where: 'date = ?', whereArgs: [date]);
  }

  // --- BACKUP & RESTORE LOGIC ---

  Future<String> performBackup() async {
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, 'ledger.db');

      // Try to get the Downloads directory
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
      } else {
        targetDir = await getDownloadsDirectory();
      }

      // Fallback if Downloads is not accessible
      if (targetDir == null || !targetDir.existsSync()) {
        targetDir = await getExternalStorageDirectory();
      }

      if (targetDir == null)
        throw Exception("Could not find storage directory");

      final backupDir = Directory('${targetDir.path}/Jp_Backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String backupFileName = "Jp_Backup_$timestamp.db";
      String backupPath = join(backupDir.path, backupFileName);

      File src = File(dbPath);
      await src.copy(backupPath);

      return backupPath;
    } catch (e) {
      throw Exception("Backup Failed: $e");
    }
  }

  Future<void> restoreBackup(String backupFilePath) async {
    try {
      final dbFolder = await getDatabasesPath();
      final dbPath = join(dbFolder, 'ledger.db');

      File backupFile = File(backupFilePath);
      if (await backupFile.exists()) {
        // Close DB connection before overwriting
        if (_database != null && _database!.isOpen) {
          await _database!.close();
          _database = null;
        }

        // Overwrite the database file
        await backupFile.copy(dbPath);

        // Re-initialize to ensure connection is fresh
        _database = await _initDB('ledger.db');
      } else {
        throw Exception("Selected backup file does not exist");
      }
    } catch (e) {
      // Attempt to reopen DB if restore fails
      _database = null;
      throw Exception("Restore Failed: $e");
    }
  }
}
