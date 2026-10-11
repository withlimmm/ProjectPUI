import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initPushNotification() async {
    // Meminta izin notifikasi (khusus iOS/Web, Android biasanya otomatis)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Dapatkan token
      String? token = await _firebaseMessaging.getToken();
      print("FCM Token: $token");
      
      if (token != null) {
        await _sendTokenToServer(token);
      }

      // Dengarkan jika token diperbarui
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _sendTokenToServer(newToken);
      });
      
      // Inisialisasi plugin notifikasi lokal untuk Foreground
      const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
      await _localNotifications.initialize(settings: initSettings);

      // Tangani notifikasi saat aplikasi terbuka (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        
        if (message.notification != null) {
          const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
          
          _localNotifications.show(
            id: message.hashCode,
            title: message.notification?.title ?? 'Notifikasi',
            body: message.notification?.body ?? '',
            notificationDetails: platformDetails,
          );
        } else if (message.data.isNotEmpty) {
           const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            importance: Importance.max,
            priority: Priority.high,
          );
          const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
          
          _localNotifications.show(
            id: message.hashCode,
            title: message.data['title'] ?? 'Notifikasi Baru',
            body: message.data['message'] ?? 'Silakan cek aplikasi Anda.',
            notificationDetails: platformDetails,
          );
        }
      });
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    
    if (userId != null) {
      try {
        final url = Uri.parse('$apiBaseUrl/profil/update-fcm/$userId');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fcm_token': token}),
        );
        if (response.statusCode == 200) {
          print("Token berhasil disimpan di server");
        } else {
          print("Gagal menyimpan token di server: ${response.body}");
        }
      } catch (e) {
        print("Error mengirim token: $e");
      }
    }
  }
}
