import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double opacity = 0.0;
  final Logger logger = Logger(); // Initialize logger

  @override
  void initState() {
    super.initState();

    // ✅ تأثير الظهور التدريجي عند تحميل الشاشة
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          opacity = 1.0;
        });
      }
    });

    navigateToNextScreen();
  }

  Future<void> navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    // ✅ التحقق مما إذا كان المستخدم مسجل الدخول
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          isLoggedIn ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);
            var slideAnimation = Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          },
        ),
      );
    } catch (e) {
      logger.e("❌ Error loading preferences: $e"); // Use logger instead of print
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(seconds: 1),
          opacity: opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 150),
              const SizedBox(height: 20),
              const Text(
                'Welcome to SMS Forwarder',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(), // ✅ مؤشر تحميل أثناء الانتظار
            ],
          ),
        ),
      ),
    );
  }
}
