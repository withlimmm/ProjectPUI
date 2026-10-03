import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';
import '../../core/services/api_config.dart';
import '../../core/services/firebase_service.dart';
import 'onboarding_screen.dart';
// Rute yang benar sesuai dengan folder Anda:
import '../customer/customer_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (!mounted) return;

    if (token != null) {
      String? userId = prefs.getString('user_id');
      if (userId != null) {
        // FCM AUTO-UPDATE (Background)
        FirebaseService().setupFCM().then((fcmToken) {
          if (fcmToken != null) {
            http.post(
              Uri.parse('${apiBaseUrl}/profil/update-fcm/$userId'),
              headers: {'Accept': 'application/json'},
              body: {'fcm_token': fcmToken},
            ).catchError((e) => print("FCM Update Error: $e"));
          }
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CustomerHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Pint Point',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            const Text(
              'LAUNDRY',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 3,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 100,
              height: 2,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
