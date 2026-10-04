import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppFirebaseService {
  static final AppFirebaseService _instance = AppFirebaseService._internal();
  factory AppFirebaseService() => _instance;
  AppFirebaseService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ==========================================
  // FASE 2: KONFIGURASI PUSH NOTIFICATION (FCM)
  // ==========================================
  
  /// Inisialisasi dan dapatkan FCM Token
  Future<String?> setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Meminta izin notifikasi (wajib untuk iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Inisialisasi Local Notifications untuk Foreground
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    
    await _localNotificationsPlugin.initialize(settings: initSettings);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await messaging.getToken();
      print("FCM Token: $token");
      
      listenToForegroundMessages();
      return token;
    }
    return null;
  }

  /// Dengarkan notifikasi saat aplikasi terbuka (Foreground)
  void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notifikasi masuk saat aplikasi terbuka: ${message.notification?.title}');
      
      if (message.notification != null) {
        _localNotificationsPlugin.show(
          id: message.notification.hashCode,
          title: message.notification!.title,
          body: message.notification!.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'Saluran untuk notifikasi penting PUI',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }

  // ==========================================
  // FASE 3: KONFIGURASI CHAT REAL-TIME (FIRESTORE)
  // ==========================================

  /// Membaca pesan chat untuk ditampilkan di UI
  Stream<QuerySnapshot> getChatStream(String orderId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Mengirim pesan ke koleksi chat
  Future<void> sendMessage(String orderId, String userId, String text) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .add({
      'sender_id': userId,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'read': false,
    });
  }

  // ==========================================
  // FASE 4: KONFIGURASI LIVE TRACKING (REALTIME DB)
  // ==========================================

  /// [Aplikasi Kurir] - Update koordinat lokasi Kurir
  Future<void> updateCourierLocation(String orderId, double lat, double lng) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("live_tracking/$orderId");
    
    await ref.update({
      "latitude": lat,
      "longitude": lng,
      "updated_at": ServerValue.timestamp,
    });
  }

  /// [Aplikasi Pelanggan] - Dengarkan Stream lokasi Kurir secara Realtime
  Stream<DatabaseEvent> listenToCourierLocation(String orderId) {
    DatabaseReference ref = FirebaseDatabase.instance.ref("live_tracking/$orderId");
    return ref.onValue;
  }
}






