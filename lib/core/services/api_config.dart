// ============================================================================
// KONFIGURASI ALAMAT API
// ============================================================================

// Menggunakan IP Lokal untuk testing
const String _baseUrl = 'https://semibiographical-bloodily-merilyn.ngrok-free.dev';

/// Mendapatkan alamat base API
String get apiBaseUrl {
  return '$_baseUrl/api';
}

/// Mendapatkan alamat base Storage
String get storageBaseUrl {
  return '$_baseUrl/storage';
}
