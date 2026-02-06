import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Backup & Restore")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.blue),
              title: const Text("Create Manual Backup"),
              subtitle: const Text("Saves database to your phone storage"),
              onTap: () async {
                if (await Permission.storage.request().isGranted) {
                  String path = await DatabaseHelper.instance.performBackup();
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Backup saved to: $path")));
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.red),
              title: const Text("Restore Data"),
              subtitle: const Text("Warning: Overwrites current data!"),
              onTap: () {
                // Here you would normally use a FilePicker to select the .db file
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text("Use a File Picker to select your .db file")));
              },
            ),
          ],
        ),
      ),
    );
  }
}
