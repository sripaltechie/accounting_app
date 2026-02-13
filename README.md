Hithvi Ledger 📒

Hithvi Ledger is a robust, offline-first mobile accounting application designed for small to medium retail businesses. Built with Flutter and SQLite, it provides a seamless way to manage daily transactions, track credit periods, and maintain financial clarity without requiring an internet connection.

🚀 Key Features

🔐 Security & Access

PIN Protection: Secure entry with a 4-6 digit PIN.

Master Reset: Built-in recovery mechanism for lost PINs.

💰 Transaction Management

Purchase & Sales: Easy entry forms with Party Name auto-complete and Credit Period tracking (in days).

Cash Flow: Dedicated Payment (Out) and Receipt (In) modules.

Invoice Linking: Smart allocation system to link payments against specific pending bills (Partial or Full clearance).

📊 Reporting

Daybook: View all transactions for a specific date chronologically.

Pending Balances: Track who owes you money, sorted by the oldest bill date to prioritize collections.

Ledger View: (Planned) Detailed transaction history per party.

🛡️ Data Safety

Offline Storage: All data is stored locally on the device using SQLite.

Auto-Backup: Background service runs daily at 7:00 AM to back up the database.

Manual Backup/Restore: Export database files to external storage for safekeeping.

🛠️ Tech Stack

Framework: Flutter (Dart)

Database: sqflite (SQLite)

Background Tasks: workmanager (For Auto-backups)

Permissions: permission_handler

Date Formatting: intl

📸 Screenshots

Login Screen

Dashboard

Payment Entry

(Add Screenshot)

(Add Screenshot)

(Add Screenshot)

⚙️ Installation & Setup

Prerequisites:

Flutter SDK installed (Guide)

Android Studio / VS Code configured

An Android device or Emulator

Clone the Repository:

git clone [https://github.com/yourusername/hithvi-ledger.git](https://github.com/yourusername/hithvi-ledger.git)
cd hithvi-ledger


Install Dependencies:

flutter pub get


Run the App:

flutter run


Build APK (Release):

flutter build apk --release --split-per-abi


🧩 Usage Guide

First Launch: The default PIN is 1234. You can change this in the settings.

Master Reset: If you forget your PIN, use the master code 900066860 to reset it.

Adding a Bill: Go to Purchase/Sales -> Select Date -> Enter Party -> Enter Credit Period (Days).

Clearing Dues: Go to Receipt/Payment -> Select Party. The app will fetch pending bills. Check the bills you want to pay against.

📂 Project Structure

lib/
├── main.dart             # Entry point & Routes
├── database_helper.dart  # SQLite Database & Linking Logic
├── dashboard.dart        # Main Menu Grid
├── login_page.dart       # Authentication Logic
├── transaction_page.dart # Purchase/Sales Entry
├── payment_page.dart     # Receipt/Payment with Linking
├── daybook_page.dart     # Daily Transaction Report
└── balance_page.dart     # Outstanding Dues Report


🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request.

📄 License

This project is licensed under the MIT License - see the LICENSE file for details.