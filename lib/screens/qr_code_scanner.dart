import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  QRCodeScannerScreenState createState() => QRCodeScannerScreenState();
}

class QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  bool isScanning = true; 
  bool hasError = false;

  Future<void> loginWithToken(String token) async {
    if (!mounted) return;

    setState(() {
      isScanning = false; 
      hasError = false;
    });

    try {
      final response = await http.post(
        Uri.parse("https://mr-hatem.com/auth.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('userToken', token);

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
          showErrorDialog("فشل التحقق: ${data["message"]}");
        }
      } else {
        showErrorDialog("خطأ في الاتصال بالسيرفر");
      }
    } catch (e) {
      showErrorDialog("حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى.");
    }
  }

  void showErrorDialog(String message) {
    if (!mounted) return;
    setState(() {
      hasError = true;
      isScanning = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("❌ خطأ"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("موافق", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void restartScan() {
    setState(() {
      isScanning = true;
      hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text("🔍 امسح رمز QR"),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  onDetect: (capture) {
                    if (isScanning) {
                      isScanning = false;
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String token = barcodes.first.rawValue ?? "";
                        loginWithToken(token);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          hasError
              ? ElevatedButton.icon(
                  onPressed: restartScan,
                  icon: const Icon(Icons.refresh),
                  label: const Text("إعادة المحاولة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : const Text(
                  "يرجى توجيه الكاميرا إلى رمز الـ QR",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
