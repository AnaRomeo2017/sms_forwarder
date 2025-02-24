import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "https://sup4fans.com";
  static const String _sendMessageEndpoint = "/suppay/vc-cash.php";

  final Dio _dio = Dio();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const MethodChannel _channel = MethodChannel('sms_forwarder');
  final Logger logger = Logger();

  ApiService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == "sendSms") {
      final Map<dynamic, dynamic> arguments = Map<String, dynamic>.from(call.arguments);
      final String sender = arguments["sender"] ?? "Unknown Sender";
      final String message = arguments["message"] ?? "No Content";
      final String receiver = arguments["receiver"] ?? "Unknown Receiver"; // ✅ استقبال `receiver`

      await sendSms(sender, message, receiver);
    }
  }

  Future<bool> sendSms(String sender, String message, String receiver) async {
    try {
      // ✅ قراءة التوكن من التخزين الآمن
      String? userToken = await _secureStorage.read(key: "userToken");
      if (userToken == null || userToken.isEmpty) {
        logger.e("❌ No user token found.");
        await _logResponse("❌ No user token found.");
        return false;
      }

      // ✅ إعداد البيانات للإرسال
      Map<String, dynamic> requestData = {
        "sender": sender,
        "receiver": receiver, // ✅ إضافة `receiver`
        "message": message,
        "token": userToken
      };

      // ✅ طباعة البيانات المرسلة للتحقق من صحتها
      logger.i("📤 Sending Data to API: ${jsonEncode(requestData)}");

      Response response = await _dio.post(
        _sendMessageEndpoint,
        data: requestData,
        options: Options(
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $userToken",
          },
          validateStatus: (status) => true,
        ),
      );

      // ✅ طباعة استجابة الـ API
      logger.i("🔹 API Response Status: ${response.statusCode}");
      logger.i("🔹 API Response Data: ${response.data}");

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData["status"] == "success") {
          logger.i("✅ Message sent successfully: ${responseData["message"]}");
          await _logResponse("✅ Message sent successfully: ${responseData["message"]}");
          return true;
        } else {
          logger.w("⚠ API Response: ${responseData["message"]}");
          await _logResponse("⚠ API Response: ${responseData["message"]}");
          return false;
        }
      } else {
        logger.e("❌ HTTP Error: ${response.statusCode}, Response: ${response.data}");
        await _logResponse("❌ HTTP Error: ${response.statusCode}, Response: ${response.data}");
        return false;
      }
    } catch (e) {
      logger.e("❌ API Error: ${e.toString()}");
      await _logResponse("❌ API Error: ${e.toString()}");
      return false;
    }
  }

  Future<void> _logResponse(String log) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList('logs') ?? [];
    logs.add("${DateTime.now()}: $log");
    await prefs.setStringList('logs', logs);
  }
}
