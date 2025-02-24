import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  LogsScreenState createState() => LogsScreenState();
}

class LogsScreenState extends State<LogsScreen> {
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      logs = prefs.getStringList('logs') ?? [];
    });
  }

  Future<void> deleteLogs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('logs');
    setState(() {
      logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () async {
              await deleteLogs();
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                "No logs available",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(logs[index]),
                  ),
                );
              },
            ),
    );
  }
}
