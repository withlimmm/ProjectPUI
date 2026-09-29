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
  // Priority 1: Ngrok (untuk testing HP fisik + Midtrans webhook)
  if (_useNgrok && _ngrokUrl.isNotEmpty) {
    return '$_ngrokUrl/api';
  }
  if (kIsWeb) {
    return 'http://127.0.0.1:$_port/api';
  }
  if (Platform.isAndroid) {
    final ip = _useEmulator ? _emulatorIp : _ipAddress;
    return 'http://$ip:$_port/api';
  }
  // Untuk iOS Simulator, iOS bisa langsung membaca localhost laptop
  return 'http://127.0.0.1:$_port/api';
}

/// Mendapatkan alamat base Storage secara dinamis
String get storageBaseUrl {
  if (_useNgrok && _ngrokUrl.isNotEmpty) {
    return '$_ngrokUrl/storage';
  }
  if (kIsWeb) {
    return 'http://127.0.0.1:$_port/storage';
  }
  if (Platform.isAndroid) {
    final ip = _useEmulator ? _emulatorIp : _ipAddress;
    return 'http://$ip:$_port/storage';
  }
  return 'http://127.0.0.1:$_port/storage';
}

