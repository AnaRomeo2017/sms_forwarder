import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController tokenController = TextEditingController();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  bool isLoading = false;
  String? errorMessage;
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // 🔹 التحقق مما إذا كان المستخدم قد سجل الدخول مسبقًا
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  // 🔹 تسجيل الدخول وحفظ بيانات المستخدم
  Future<void> loginWithToken(String token) async {
    if (token.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse("https://sup4fans.com/suppay/auth.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          await secureStorage.write(key: "userToken", value: token);

          // 🔹 حفظ حالة تسجيل الدخول
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        } else {
          setState(() {
            errorMessage = data["message"];
          });
        }
      } else {
        setState(() {
          errorMessage = "خطأ في الاتصال بالسيرفر";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ أثناء تسجيل الدخول";
      });
    }
  }

  // 🔹 تسجيل الدخول عبر مسح QR
  void loginWithQR() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("امسح رمز QR"),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              if (isScanning) {
                isScanning = false;
                final token = capture.barcodes.first.rawValue ?? "";
                Navigator.pop(context);
                loginWithToken(token);
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 120),
              const SizedBox(height: 20),
              const Text(
                "تسجيل الدخول",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: tokenController,
                decoration: InputDecoration(
                  labelText: "أدخل التوكن",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.security),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              if (errorMessage != null)
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              const SizedBox(height: 15),
              isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: () => loginWithToken(tokenController.text.trim()),
                icon: const Icon(Icons.vpn_key),
                label: const Text("تسجيل الدخول بـ Token"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loginWithQR,
                icon: const Icon(Icons.qr_code, color: Colors.blue),
                label: const Text("تسجيل الدخول عبر QR"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: const BorderSide(color: Colors.blueAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
