import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'package:sms_forwarder/services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel channel = MethodChannel('sms_forwarder');
  final ApiService apiService = ApiService();
  final Logger logger = Logger(); // Initialize logger

  List<Map<String, String>> messages = [];
  List<Map<String, String>> filteredMessages = [];
  String userToken = "";
  bool isForwardingEnabled = true;
  List<String> senderFilters = [];
  List<String> contentFilters = [];

  @override
  void initState() {
    super.initState();
    requestSmsPermission();
    initializeNotifications();
    loadPreferences();
    fetchAllMessages();
    channel.setMethodCallHandler(_handleMethodCall);
  }

  // Request SMS read permission
  Future<void> requestSmsPermission() async {
    final Telephony telephony = Telephony.instance;
    bool? isGranted = await telephony.requestSmsPermissions;
    if (isGranted != true) {
      if (mounted) {
        showPermissionDialog();
      }
    }
  }

  // Show permission dialog if permission is denied
  void showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("مطلوب إذن الوصول"),
        content: const Text("يرجى منح الإذن لقراءة الرسائل القصيرة حتى يعمل التطبيق بشكل صحيح."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              requestSmsPermission(); // Retry request after closing
            },
            child: const Text("إعادة المحاولة"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
        ],
      ),
    );
  }

  void initializeNotifications() {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    notificationsPlugin.initialize(settings);
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedToken = await secureStorage.read(key: "userToken");

    if (!mounted) return;
    setState(() {
      isForwardingEnabled = prefs.getBool('isForwardingEnabled') ?? true;
      senderFilters = prefs.getStringList('senderFilters') ?? [];
      contentFilters = prefs.getStringList('contentFilters') ?? [];
      userToken = storedToken ?? "";
    });
    applyFilters();
  }

  Future<void> loadMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedMessages = prefs.getString('messages');
    if (storedMessages != null) {
      if (!mounted) return;
      setState(() {
        messages = List<Map<String, String>>.from(json.decode(storedMessages));
      });
      applyFilters();
    }
  }

  Future<void> saveMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('messages', json.encode(messages));
  }

  // Handle method calls from `SmsReceiver.java` via `MethodChannel`
  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == "onSmsReceived") {
      try {
        final Map<String, dynamic> smsData = Map<String, dynamic>.from(call.arguments);
        final String sender = smsData["sender"] ?? "Unknown Sender";
        final String message = smsData["message"] ?? "No Content";
        final String receiver = smsData["receiver"] ?? "+201000000000";

        logger.i("📩 SMS Received - Sender: $sender, Receiver: $receiver, Message: $message");

        addMessage(sender, message, receiver);

        // Check if the message is new and send to API
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? lastSender = prefs.getString('last_sent_sender');
        String? lastMessage = prefs.getString('last_sent_message');
        String? lastReceiver = prefs.getString('last_sent_receiver');

        if (sender != lastSender || message != lastMessage || receiver != lastReceiver) {
          await apiService.sendSms(sender, message, receiver);
          prefs.setString('last_sent_sender', sender);
          prefs.setString('last_sent_message', message);
          prefs.setString('last_sent_receiver', receiver);
        }
      } catch (e) {
        logger.e("❌ Error processing received SMS: $e");
      }
    }
  }

  Future<void> fetchAllMessages() async {
    try {
      final List<dynamic> messages = await channel.invokeMethod('fetchAllSms');
      for (var message in messages) {
        final Map<String, dynamic> smsData = Map<String, dynamic>.from(message);
        final String sender = smsData["sender"] ?? "Unknown Sender";
        final String content = smsData["content"] ?? "No Content";
        final String receiver = smsData["receiver"] ?? "+201000000000";
        final String dateReceived = smsData["date_received"] ?? "Unknown Date";
        final String status = smsData["status"] ?? "unknown";

        addMessage(sender, content, receiver, dateReceived, status);
      }
      logger.d("✅ All old messages loaded successfully.");
    } catch (e) {
      logger.e("❌ Error fetching old messages: $e");
    }
  }

  // Check if the message should be forwarded based on filters
  bool shouldForwardMessage(String sender, String message) {
    bool senderMatches = senderFilters.isEmpty || senderFilters.any((filter) => sender.contains(filter));
    bool contentMatches = contentFilters.isEmpty || contentFilters.any((filter) => message.contains(filter));
    return senderMatches && contentMatches;
  }

  // Update UI when a new message is received
  void addMessage(String sender, String content, String receiver, [String? dateReceived, String? status]) {
    if (!mounted) return;
    // Check for duplicates
    bool isDuplicate = messages.any((msg) => msg["sender"] == sender && msg["content"] == content);
    if (!isDuplicate) {
      setState(() {
        messages.insert(0, {
          "sender": sender,
          "content": content,
          "receiver": receiver,
          "date_received": dateReceived ?? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          "status": status ?? "pending"
        });
      });
      saveMessages();
      applyFilters();
    }
  }

  // Apply filters to messages
  void applyFilters() {
    if (!mounted) return;
    setState(() {
      filteredMessages = messages.where((msg) {
        bool senderMatches = senderFilters.isEmpty || senderFilters.any((filter) => msg["sender"]!.contains(filter));
        bool contentMatches = contentFilters.isEmpty || contentFilters.any((filter) => msg["content"]!.contains(filter));
        return senderMatches && contentMatches;
      }).toList();
    });
  }

  // Forward the message to the API after receiving it
  Future<void> forwardMessage(String sender, String message, String receiver) async {
    bool success = await apiService.sendSms(sender, message, receiver);

    if (!mounted) return;
    setState(() {
      messages[0]["status"] = success ? "تم الإرسال" : "فشل";
    });
    saveMessages();
    applyFilters();

    if (!success) {
      showNotification("فشل في إرسال الرسالة", "لم يتم إرسال الرسالة من $sender.");
    }
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

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await secureStorage.delete(key: "userToken");

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> resendMessage(int index) async {
    final message = filteredMessages[index];
    bool success = await apiService.sendSms(message["sender"]!, message["content"]!, message["receiver"]!);

    if (!mounted) return;
    setState(() {
      messages[index]["status"] = success ? "تم الإرسال" : "فشل";
    });
    saveMessages();
    applyFilters();

    if (!success) {
      showNotification("فشل في إعادة إرسال الرسالة", "لم يتم إعادة إرسال الرسالة من ${message["sender"]}.");
    }
  }

  void showMessageDetails(BuildContext context, Map<String, String> message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("تفاصيل الرسالة", textAlign: TextAlign.right),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("المرسل: ${message["sender"]}", textAlign: TextAlign.right),
            Text("المصدر: ${message["sender"]}", textAlign: TextAlign.right),
            Text("المحتوى: ${message["content"]}", textAlign: TextAlign.right),
            Text("تاريخ الاستلام: ${message["date_received"]}", textAlign: TextAlign.right),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await resendMessage(filteredMessages.indexOf(message));
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("إعادة الإرسال"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("إغلاق"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("الرسائل المستلمة"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              if (mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
                loadPreferences();
              }
            },
          ),
          Switch(
            value: isForwardingEnabled,
            activeColor: Colors.white,
            onChanged: (value) async {
              if (mounted) {
                setState(() {
                  isForwardingEnabled = value;
                });
              }
              SharedPreferences prefs = await SharedPreferences.getInstance();
              prefs.setBool('isForwardingEnabled', value);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          ),
        ],
      ),
      body: filteredMessages.isEmpty
          ? const Center(
              child: Text(
                "لا توجد رسائل متاحة",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final message = filteredMessages[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.message, color: Colors.blueAccent),
                    title: Text(
                      message["sender"]!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("SIM In: ${message["receiver"]}", textAlign: TextAlign.right),
                        Text(
                          "المحتوى: ${message["content"]!.length > 80 ? message["content"]!.substring(0, 80) + '...' : message["content"]}",
                          textAlign: TextAlign.right,
                        ),
                        Text("تاريخ الاستلام: ${message["date_received"]}", textAlign: TextAlign.right),
                        Text("الحالة: ${message["status"]}", textAlign: TextAlign.right),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          messages.removeAt(index);
                          saveMessages();
                          applyFilters();
                        });
                      },
                    ),
                    onTap: () => showMessageDetails(context, message),
                  ),
                );
              },
            ),
    );
  }
}
