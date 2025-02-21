import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart' show DateFormat;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'settings_screen.dart';

void main() {
  runApp(const MaterialApp(
    home: HomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  List<Map<String, String>> messages = [];
  String userToken = "";
  bool isForwardingEnabled = true;
  List<String> senderFilters = [];
  List<String> contentFilters = [];
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    initializeNotifications();
    loadPreferences();
    listenForSms();
  }

  void initializeNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    notificationsPlugin.initialize(settings);
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await notificationsPlugin.show(0, title, body, details);
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isForwardingEnabled = prefs.getBool('isForwardingEnabled') ?? true;
      senderFilters = prefs.getStringList('senderFilters') ?? [];
      contentFilters = prefs.getStringList('contentFilters') ?? [];
      userToken = prefs.getString('userToken') ?? "";
    });
  }

  void listenForSms() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (!shouldFilterMessage(message.address ?? '', message.body ?? '')) {
          setState(() {
            messages.insert(0, {
              "sender": message.address ?? "Unknown",
              "content": message.body ?? "No Content",
              "date_received": DateFormat('yyyy-MM-dd HH:mm:ss')
                  .format(DateTime.now()),
              "status": "pending"
            });
          });
          forwardMessage(messages[0]);
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  static void backgroundMessageHandler(SmsMessage message) {
    print("Received SMS in background: ${message.body}");
  }

  bool shouldFilterMessage(String sender, String content) {
    for (var filter in senderFilters) {
      if (sender.contains(filter)) return true;
    }
    for (var filter in contentFilters) {
      if (content.contains(filter)) return true;
    }
    return false;
  }

  Future<void> forwardMessage(Map<String, String> message) async {
    if (!isForwardingEnabled || userToken.isEmpty) return;

    final response = await http.post(
      Uri.parse("https://mr-hatem.com/send-message"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "token": userToken,
        "sender": message["sender"],
        "content": message["content"],
        "date_received": message["date_received"],
      }),
    );

    setState(() {
      message["status"] = response.statusCode == 200 ? "sent" : "failed";
    });

    if (response.statusCode != 200) {
      showNotification(
          "فشل إرسال الرسالة", "لم يتم إرسال الرسالة من ${message["sender"]}.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("📩 الرسائل المستلمة"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                ),
              );
              loadPreferences();
            },
          ),
          Switch(
            value: isForwardingEnabled,
            activeColor: Colors.white,
            onChanged: (value) {
              setState(() {
                isForwardingEnabled = value;
              });
              SharedPreferences.getInstance().then((prefs) {
                prefs.setBool('isForwardingEnabled', value);
              });
            },
          ),
        ],
      ),
      body: messages.isEmpty
          ? const Center(
              child: Text(
                "لا توجد رسائل متاحة",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.message, color: Colors.blueAccent),
                    title: Text(
                      message["sender"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message["content"]!),
                        Text("📥 مستلمة: ${message["date_received"]}"),
                      ],
                    ),
                    trailing: Icon(
                      message["status"] == "sent" ? Icons.check_circle : Icons.error,
                      color: message["status"] == "sent" ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
