import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  List<String> senderFilters = [];
  List<String> contentFilters = [];
  String selectedSim = "both";

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedSim = prefs.getString('selectedSim') ?? "both";
      senderFilters = prefs.getStringList('senderFilters') ?? [];
      contentFilters = prefs.getStringList('contentFilters') ?? [];
    });
  }

  Future<void> savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('selectedSim', selectedSim);
    prefs.setStringList('senderFilters', senderFilters);
    prefs.setStringList('contentFilters', contentFilters);
  }

  void addFilter(String type) {
    TextEditingController filterController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          type == "sender" ? "إضافة فلتر حسب الراسل" : "إضافة فلتر حسب النص",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: filterController,
          decoration: InputDecoration(
            labelText: type == "sender" ? "أدخل رقم أو اسم الراسل" : "أدخل الكلمة المطلوبة",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (filterController.text.isNotEmpty) {
                setState(() {
                  if (type == "sender") {
                    senderFilters.add(filterController.text.trim());
                  } else {
                    contentFilters.add(filterController.text.trim());
                  }
                });
                savePreferences();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("إضافة"),
          ),
        ],
      ),
    );
  }

  void removeFilter(String type, int index) {
    setState(() {
      if (type == "sender") {
        senderFilters.removeAt(index);
      } else {
        contentFilters.removeAt(index);
      }
    });
    savePreferences();
  }

  void showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blueAccent),
            title: const Text("فلتر حسب الراسل"),
            onTap: () {
              Navigator.pop(context);
              addFilter("sender");
            },
          ),
          ListTile(
            leading: const Icon(Icons.text_fields, color: Colors.green),
            title: const Text("فلتر حسب النص"),
            onTap: () {
              Navigator.pop(context);
              addFilter("content");
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("⚙️ الإعدادات"),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "اختر شريحة الرسائل:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSim,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: "sim1", child: Text("SIM 1")),
                DropdownMenuItem(value: "sim2", child: Text("SIM 2")),
                DropdownMenuItem(value: "both", child: Text("كلاهما")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedSim = value!;
                });
                savePreferences();
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    "📩 فلاتر حسب الراسل:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (senderFilters.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("لا يوجد فلاتر مضافة"),
                      ),
                    ),
                  ...senderFilters.map((filter) {
                    int index = senderFilters.indexOf(filter);
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(filter),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeFilter("sender", index),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Text(
                    "🔍 فلاتر حسب النص:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (contentFilters.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("لا يوجد فلاتر مضافة"),
                      ),
                    ),
                  ...contentFilters.map((filter) {
                    int index = contentFilters.indexOf(filter);
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(filter),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => removeFilter("content", index),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showFilterOptions,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
