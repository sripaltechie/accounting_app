import 'package:flutter/material.dart';
import 'database_helper.dart';

class PartyPage extends StatefulWidget {
  @override
  _PartyPageState createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  List<Map<String, dynamic>> _parties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshParties();
  }

  void _refreshParties() async {
    final data = await DatabaseHelper.instance.getAllParties();
    setState(() {
      _parties = data;
      _isLoading = false;
    });
  }

  void _showPartyForm({Map<String, dynamic>? existingParty}) {
    final nameController = TextEditingController(
        text: existingParty != null ? existingParty['name'] : '');
    final mobileController = TextEditingController(
        text: existingParty != null ? existingParty['mobile'] : '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(existingParty == null ? "Create Party" : "Edit Party",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: "Party Name", border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? "Enter Name" : null,
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: "Mobile Number",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone)),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        if (existingParty == null) {
                          await DatabaseHelper.instance.insertParty({
                            'name': nameController.text.trim(),
                            'mobile': mobileController.text.trim()
                          });
                        } else {
                          await DatabaseHelper.instance.updateParty({
                            'id': existingParty['id'],
                            'name': nameController.text.trim(),
                            'mobile': mobileController.text.trim()
                          });
                        }
                        Navigator.pop(context);
                        _refreshParties();
                      }
                    },
                    child: Text(existingParty == null ? "CREATE" : "UPDATE"),
                    style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        });
  }

  void _deleteParty(int id) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Party?"),
        content:
            Text("This will NOT delete their transactions, only the contact."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteParty(id);
              Navigator.pop(ctx);
              _refreshParties();
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Party Management")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _parties.isEmpty
              ? Center(child: Text("No parties found. Add one!"))
              : ListView.builder(
                  itemCount: _parties.length,
                  itemBuilder: (context, index) {
                    final party = _parties[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(party['name'][0].toUpperCase())),
                        title: Text(party['name'],
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Mobile: ${party['mobile'] ?? 'N/A'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showPartyForm(existingParty: party)),
                            IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteParty(party['id'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPartyForm(),
        child: Icon(Icons.add),
        tooltip: "Create Party",
      ),
    );
  }
}
