import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Backup & Restore")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.backup, color: Colors.blue),
              title: Text("Create Manual Backup"),
              subtitle: Text("Saves database to your phone storage"),
              onTap: () async {
                if (await Permission.storage.request().isGranted) {
                  String path = await DatabaseHelper.instance.performBackup();
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Backup saved to: $path")));
                }
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.restore, color: Colors.red),
              title: Text("Restore Data"),
              subtitle: Text("Warning: Overwrites current data!"),
              onTap: () {
                // Here you would normally use a FilePicker to select the .db file
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
