import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Jumlah notifikasi & chat yang belum dibaca untuk user yang sedang login.
class BadgeCounts {
  final int notif;
  final int chat;
  const BadgeCounts(this.notif, this.chat);

  static const zero = BadgeCounts(0, 0);

  @override
  bool operator ==(Object other) =>
      other is BadgeCounts && other.notif == notif && other.chat == chat;

  @override
  int get hashCode => Object.hash(notif, chat);
}

/// Service ringan untuk badge notifikasi/chat (dipoll berkala dari endpoint `/badge`).
class BadgeService {
  BadgeService._();

  static final ValueNotifier<BadgeCounts> counts = ValueNotifier(
    BadgeCounts.zero,
  );
  static Timer? _timer;

  /// Mulai polling (aman dipanggil berkali-kali).
  static void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => refresh());
    refresh();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    counts.value = BadgeCounts.zero;
  }

  static Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        counts.value = BadgeCounts.zero;
        return;
      }

      final res = await http
          .get(Uri.parse('$apiBaseUrl/badge'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        counts.value = BadgeCounts(
          (json['notif_unread'] ?? 0) as int,
          (json['chat_unread'] ?? 0) as int,
        );
      }
    } catch (_) {
      // Abaikan error jaringan sementara; badge akan diperbarui pada polling berikutnya.
    }
  }
}
