import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class BackupPage extends StatelessWidget {
  // Request storage permissions with fallback to settings
  Future<bool> _requestPermission(BuildContext context) async {
    if (Platform.isAndroid) {
      // 1. Check for Android 11+ (All Files Access)
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      // 2. Check for Android 10 and below (Standard Storage)
      // Note: On Android 13+, Permission.storage only covers media.
      // But manageExternalStorage (above) handles the "All Files" case.
      if (await Permission.storage.request().isGranted) {
        return true;
      }

      // 3. If we are here, permission is denied.
      // Check if we need to open settings (e.g. "Don't ask again" was selected)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Storage permission is required to save backups."),
          action: SnackBarAction(
            label: "Settings",
            onPressed: () => openAppSettings(),
          ),
          duration: Duration(seconds: 5),
        ));
      }
      return false;
    }
    return true;
  }

  void _handleBackup(BuildContext context) async {
    bool hasPermission = await _requestPermission(context);

    if (hasPermission) {
      try {
        String path = await DatabaseHelper.instance.performBackup();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Backup Success!\nSaved to: $path"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Backup Failed: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _handleRestore(BuildContext context) async {
    // 1. Pick File
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select Backup File (.db)",
    );

    if (result != null) {
      String? path = result.files.single.path;
      if (path != null) {
        // 2. Confirm Action
        bool confirm = await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: Text("Restore Data?"),
                      content: Text(
                          "Warning: This will DELETE all current data on this device and replace it with the backup. This cannot be undone."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text("Cancel")),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text("Restore",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold))),
                      ],
                    )) ??
            false;

        if (confirm) {
          try {
            await DatabaseHelper.instance.restoreBackup(path);

            await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                      title: Text("Restore Complete"),
                      content:
                          Text("The app needs to restart to apply changes."),
                      actions: [
                        TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              // In a real app, you might trigger a full state reload or exit
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/', (route) => false);
                            },
                            child: Text("Restart App"))
                      ],
                    ));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text("Restore Failed: $e"),
                backgroundColor: Colors.red));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Backup & Restore")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!)),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "Backups are saved to your 'Downloads/jp_Backups' folder."))
                ],
              ),
            ),
            SizedBox(height: 20),

            // Backup Button
            Card(
              elevation: 4,
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.upload, color: Colors.white)),
                title: Text("Create Backup"),
                subtitle: Text("Save current data to storage"),
                onTap: () => _handleBackup(context),
              ),
            ),
            SizedBox(height: 15),

            // Restore Button
            Card(
              elevation: 4,
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.download, color: Colors.white)),
                title: Text("Restore Backup"),
                subtitle: Text("Import .db file from storage"),
                onTap: () => _handleRestore(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
