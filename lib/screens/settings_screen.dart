import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logs_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  List<String> senderFilters = [];
  List<String> contentFilters = [];
  String selectedSim = "both";
  final TextEditingController senderController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      senderFilters = prefs.getStringList('senderFilters') ?? [];
      contentFilters = prefs.getStringList('contentFilters') ?? [];
      selectedSim = prefs.getString('selectedSim') ?? "both";
    });
  }

  Future<void> savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('senderFilters', senderFilters);
    await prefs.setStringList('contentFilters', contentFilters);
    await prefs.setString('selectedSim', selectedSim);
  }

  void addSenderFilter() {
    if (senderController.text.isNotEmpty) {
      setState(() {
        senderFilters.add(senderController.text);
        senderController.clear();
      });
      savePreferences();
    }
  }

  void addContentFilter() {
    if (contentController.text.isNotEmpty) {
      setState(() {
        contentFilters.add(contentController.text);
        contentController.clear();
      });
      savePreferences();
    }
  }

  void removeSenderFilter(int index) {
    setState(() {
      senderFilters.removeAt(index);
    });
    savePreferences();
  }

  void removeContentFilter(int index) {
    setState(() {
      contentFilters.removeAt(index);
    });
    savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Sender Filters",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: senderController,
            decoration: InputDecoration(
              labelText: "Add Sender Filter",
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: addSenderFilter,
              ),
            ),
          ),
          Wrap(
            spacing: 8.0,
            children: List.generate(senderFilters.length, (index) {
              return Chip(
                label: Text(senderFilters[index]),
                onDeleted: () => removeSenderFilter(index),
              );
            }),
          ),
          const SizedBox(height: 16.0),
          const Text(
            "Content Filters",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: contentController,
            decoration: InputDecoration(
              labelText: "Add Content Filter",
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: addContentFilter,
              ),
            ),
          ),
          Wrap(
            spacing: 8.0,
            children: List.generate(contentFilters.length, (index) {
              return Chip(
                label: Text(contentFilters[index]),
                onDeleted: () => removeContentFilter(index),
              );
            }),
          ),
          const SizedBox(height: 16.0),
          const Text(
            "Selected SIM",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
            value: selectedSim,
            onChanged: (String? newValue) {
              setState(() {
                selectedSim = newValue!;
              });
              savePreferences();
            },
            items: <String>['both', 'sim1', 'sim2']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),
          ListTile(
            title: const Text("View Logs"),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
