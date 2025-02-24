import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();
final Logger logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  await initializeService();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

Future<void> requestPermissions() async {
  await [
    Permission.sms,
    Permission.storage,
  ].request();
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const MethodChannel channel = MethodChannel('sms_forwarder');
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    channel.setMethodCallHandler(_handleMethodCall);
    fetchAllSms();
    processStoredMessages();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == "onSmsReceived") {
      try {
        // Receive data as a map instead of a string
        final Map<String, dynamic> smsData = Map<String, dynamic>.from(call.arguments);
        final String sender = smsData["sender"] ?? "Unknown Sender";
        final String message = smsData["message"] ?? "No Content";
        final String receiver = smsData["receiver"]?.isNotEmpty == true ? smsData["receiver"]! : "+201000000000"; // ✅ تعديل `receiver`

        logger.i("📩 SMS Received - Sender: $sender, Receiver: $receiver, Message: $message");

        homeScreenKey.currentState!.addMessage(sender, message, receiver);

        // Send data to API
        await apiService.sendSms(sender, message, receiver);
      } catch (e) {
        logger.e("❌ Error processing received SMS: $e");
      }
    }
  }

  // Fetch all old messages from Java
  Future<void> fetchAllSms() async {
    try {
      final List<dynamic> messages = await channel.invokeMethod('fetchAllSms');
      for (var message in messages) {
        final Map<String, dynamic> smsData = Map<String, dynamic>.from(message);
        final String sender = smsData["sender"] ?? "Unknown Sender";
        final String content = smsData["content"] ?? "No Content";
        final String receiver = smsData["receiver"]?.isNotEmpty == true ? smsData["receiver"]! : "+201000000000"; // ✅ تعديل `receiver`
        final String dateReceived = smsData["date_received"] ?? "Unknown Date";
        final String status = smsData["status"] ?? "unknown";

        homeScreenKey.currentState!.addMessage(sender, content, receiver, dateReceived, status);
      }
      logger.d("✅ All old messages loaded successfully.");
    } catch (e) {
      logger.e("❌ Error fetching old messages: $e");
    }
  }

  Future<void> processStoredMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? sender = prefs.getString('last_sms_sender');
    String? message = prefs.getString('last_sms_message');
    String? receiver = prefs.getString('last_sms_receiver')?.isNotEmpty == true ? prefs.getString('last_sms_receiver')! : "+201000000000"; // ✅ تعديل `receiver`

    if (sender != null && message != null) {
      homeScreenKey.currentState!.addMessage(sender, message, receiver);

      await apiService.sendSms(sender, message, receiver);

      prefs.remove('last_sms_sender');
      prefs.remove('last_sms_message');
      prefs.remove('last_sms_receiver'); // Clear `receiver` after processing
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS Forwarder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        brightness: Brightness.dark,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService(); // Correct method to start the service
}

void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.invoke('update', {'status': 'Running'});

  const MethodChannel channel = MethodChannel('sms_forwarder');
  channel.setMethodCallHandler((call) async {
    if (call.method == "onSmsReceived") {
      final Map<String, dynamic> smsData = Map<String, dynamic>.from(call.arguments);
      final String sender = smsData["sender"];
      final String message = smsData["message"];
      final String receiver = smsData["receiver"]?.isNotEmpty == true ? smsData["receiver"]! : "+201000000000"; // ✅ تعديل `receiver`

      logger.i("📩 Background SMS Received - Sender: $sender, Receiver: $receiver, Message: $message");

      final ApiService apiService = ApiService();
      await apiService.sendSms(sender, message, receiver);
    }
  });
}

Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
