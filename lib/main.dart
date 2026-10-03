import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/splash_screen.dart';

// Menangani notifikasi saat aplikasi berjalan di background/ditutup
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const PintPointApp());
}

class PintPointApp extends StatelessWidget {
  const PintPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pint Point Laundry',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        // Jika Anda belum menambahkan font Poppins di pubspec.yaml,
        // Anda bisa menghapus atau membiarkan baris ini sementara
        fontFamily: 'Poppins',
      ),
      // Mengarahkan tampilan pertama kali dibuka ke Splash Screen
      home: const SplashScreen(),
    );
  }
}
