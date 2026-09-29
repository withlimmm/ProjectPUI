import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF039BE5); // Warna biru utama Pint Point
  static const Color primaryDark = Color(
    0xFF0277BD,
  ); // Biru gelap (opsional untuk tombol saat ditekan)
  static const Color background = Colors.white;

  // --- Penamaan teks dari struktur lama ---
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF94A3B8);

  // --- Penamaan teks dari struktur baru ---
  static const Color textDark = Color(
    0xFF1E293B,
  ); // Untuk teks judul / teks utama
  static const Color textLight = Color(
    0xFF64748B,
  ); // Untuk teks deskripsi / placeholder

  // Warna abu-abu terang untuk kolom input form
  static const Color inputFill = Color(0xFFF4F6F9);
}
