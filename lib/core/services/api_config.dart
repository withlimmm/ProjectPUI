import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// ============================================================================
// KONFIGURASI ALAMAT API (CENTRALIZED)
// ============================================================================
const String _ipAddress = '172.20.10.7'; // IP Laptop jika pakai HP fisik
const String _emulatorIp = '10.0.2.2'; // IP default Emulator Android
const String _port = '8000'; // Port Server Laravel
const bool _useEmulator = true; // WAJIB TRUE jika pakai emulator

// --- NGROK SUPPORT ---
// Saat testing dengan HP fisik + Midtrans webhook, gunakan ngrok:
// 1. Jalankan: ngrok http 8000
// 2. Salin URL https dari ngrok (contoh: https://abc123.ngrok-free.app)
// 3. Isi _ngrokUrl dengan URL tersebut
// 4. Set _useNgrok = true
const bool _useNgrok = true; // ← Ganti true saat pakai ngrok
const String _ngrokUrl = 'https://uptake-jam-hypocrite.ngrok-free.dev'; // ← Isi URL ngrok di sini (tanpa trailing slash)

/// Mendapatkan alamat base API secara dinamis
String get apiBaseUrl {
  return 'https://pintpoint.rakiradigital.com/api';
}

/// Mendapatkan alamat base Storage secara dinamis
String get storageBaseUrl {
  return 'https://pintpoint.rakiradigital.com/storage';
}


