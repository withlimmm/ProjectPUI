// ============================================================================
// 🚀 MIDTRANS PAYMENT INTEGRATION - SETUP GUIDE
// ============================================================================
// In-App Payment Gateway (Bukan Redirect Web)

// ✅ APA YANG SUDAH DIBUAT:

// 1️⃣ FLUTTER SIDE (Sudah Selesai)
//    ✓ pubspec.yaml - Tambah midtrans_sdk package
//    ✓ lib/core/services/midtrans_service.dart - Payment service
//    ✓ lib/features/customer/customer_payment_screen.dart - In-app payment UI

// 2️⃣ BACKEND SIDE (Harus Anda Setup)
//    ⏳ Midtrans PHP Library
//    ⏳ MidtransController di Laravel
//    ⏳ Routes untuk Midtrans endpoints
//    ⏳ Webhook setup di Midtrans Dashboard

// ============================================================================
// ⚠️ PENTING: Sebelum Testing, Setup Backend Terlebih Dahulu!
// ============================================================================

// LANGKAH 1: Install Midtrans Library
// ─────────────────────────────────────
// Buka terminal Laravel:
// cd C:\path\to\pint-point-backend
// composer require midtrans/midtrans-php

// LANGKAH 2: Ambil Midtrans Credentials
// ──────────────────────────────────────
// 1. Buka https://midtrans.com
// 2. Login atau Daftar akun
// 3. Settings > API Keys
// 4. Copy Server Key (SB-Mid-server-...)
// 5. Copy Client Key (SB-Mid-client-...)

// LANGKAH 3: Update .env di Backend
// ───────────────────────────────────
// Tambah ke .env:
// MIDTRANS_SERVER_KEY=SB-Mid-server-XXXXXXXXXXXXX
// MIDTRANS_CLIENT_KEY=SB-Mid-client-XXXXXXXXXXXXX
// MIDTRANS_IS_PRODUCTION=false

// LANGKAH 4: Update Flutter Config
// ─────────────────────────────────
// File: lib/core/services/midtrans_service.dart
// Ubah:
// static const String _serverKey = "SB-Mid-server-XXXXXXXXXXXXX";
// static const String _clientKey = "SB-Mid-client-XXXXXXXXXXXXX";

// LANGKAH 5: Setup Backend Controller
// ────────────────────────────────────
// Copy kode dari: lib/core/services/MIDTRANS_SETUP_BACKEND.dart
// Ikuti setiap step yang ada di dokumentasi

// LANGKAH 6: Setup Routes di Laravel
// ──────────────────────────────────
// Tambah ke routes/api.php (lihat MIDTRANS_SETUP_BACKEND.dart)

// LANGKAH 7: Setup Webhook di Midtrans Dashboard
// ──────────────────────────────────────────────
// 1. Login ke Midtrans Dashboard
// 2. Settings > Notification URL
// 3. Masukkan: http://192.168.1.7:8000/api/midtrans/webhook
// 4. Test webhook

// ============================================================================
// 🎯 PAYMENT FLOW YANG AKAN TERJADI:
// ============================================================================

// 1. User klik "Lanjut ke Pembayaran"
//    ↓
// 2. Flutter app request token ke backend
//    ↓
// 3. Backend generate token Midtrans
//    ↓
// 4. Flutter app tampilkan Midtrans payment UI (IN-APP)
//    ↓
// 5. User pilih metode pembayaran
//    ↓
// 6. User melakukan pembayaran
//    ↓
// 7. Midtrans kirim callback ke backend webhook
//    ↓
// 8. Backend update status pesanan menjadi "PAID"
//    ↓
// 9. Event PaymentSuccessful triggered
//    ↓
// 10. Flutter app menampilkan "Pembayaran Berhasil!"
//    ↓
// 11. Admin panel menerima notifikasi pembayaran
//    ↓
// 12. Admin dapat mulai proses laundry

// ============================================================================
// 💳 METODE PEMBAYARAN YANG TERSEDIA:
// ============================================================================
// • Transfer Bank (Semua Bank)
// • E-Wallet (GCash, OVO, DANA, LinkAja, dll)
// • Kartu Kredit/Debit
// • Cicilan (Tenor)
// • Virtual Account

// ============================================================================
// ✅ CHECKLIST SETUP:
// ============================================================================

// [ ] 1. Install midtrans_sdk package (sudah di pubspec.yaml)
// [ ] 2. Download Midtrans PHP Library (composer require)
// [ ] 3. Buat MidtransController di Laravel
// [ ] 4. Setup routes untuk Midtrans endpoints
// [ ] 5. Update .env dengan Midtrans credentials
// [ ] 6. Update midtrans_service.dart dengan client key
// [ ] 7. Setup webhook di Midtrans Dashboard
// [ ] 8. Migration untuk payment fields di database
// [ ] 9. Update Model Pesanan
// [ ] 10. Create PaymentSuccessful Event
// [ ] 11. Test payment flow end-to-end

// ============================================================================
// 🧪 TESTING PAYMENT:
// ============================================================================

// Sandbox Testing (GRATIS, tidak real money):

// 1. Selesaikan setup backend terlebih dahulu
// 2. Pastikan MIDTRANS_IS_PRODUCTION=false
// 3. Jalankan Flutter app
// 4. Buat pesanan
// 5. Klik "Lanjut ke Pembayaran"
// 6. Pilih metode pembayaran
// 7. Gunakan kartu test:
//    - Nomor: 4111 1111 1111 1111
//    - Expiry: 12/25
//    - CVV: 123
// 8. Selesaikan pembayaran
// 9. Cek database bahwa status_pembayaran berubah ke "paid"
// 10. Cek admin panel mendapat notifikasi

// ============================================================================
// 📱 UI FLOW DI APLIKASI:
// ============================================================================

// BEFORE (Web Redirect):
// Pesanan → Bayar → Redirect ke browser → Bayar → Back to App

// AFTER (In-App Payment):
// Pesanan → Bayar → Midtrans Payment UI (dalam app) → Pilih metode
// → Bayar → Notifikasi Sukses → Kembali ke app

// User tidak perlu keluar dari aplikasi! 🎉

// ============================================================================
// 📊 ADMIN PANEL INTEGRATION:
// ============================================================================

// Admin akan menerima notifikasi real-time ketika:
// 1. Ada pesanan baru yang dibayar
// 2. Status pembayaran berubah
// 3. Perlu mulai proses laundry

// Implementasi di Admin:
// 1. Listen untuk PaymentSuccessful event
// 2. Update dashboard dengan order terbaru
// 3. Kirim notifikasi ke admin
// 4. Update status pesanan otomatis

// ============================================================================
// ⚠️ PRODUCTION MIGRATION:
// ============================================================================

// Ketika siap go-live:

// 1. Buat akun Midtrans production
// 2. Dapatkan live Server Key & Client Key
// 3. Update .env:
//    MIDTRANS__IS_PRODUCTION=true
//    MIDTRANS_SERVER_KEY=Mid-server-live-XXXXX
//    MIDTRANS_CLIENT_KEY=Mid-client-live-XXXXX

// 4. Update midtrans_service.dart:
//    environment: MidtransEnvironment.production,

// 5. Setup production webhook URL
// 6. Test dengan real transactions
// 7. Monitor dan handle errors

// ============================================================================
// 🆘 SUPPORT & TROUBLESHOOTING:
// ============================================================================

// Midtrans Documentation: https://docs.midtrans.com
// Forum: https://forum.midtrans.com
// WhatsApp Support: 1. Midtrans (ID): +62-21-29321777

// Common Issues:
// 1. "Invalid client key" → Pastikan client key benar
// 2. "Token expired" → Generate token baru
// 3. "Webhook not triggered" → Setup notification URL
// 4. "Payment timeout" → Increase timeout duration

// ============================================================================

// STATUS: ✅ FLUTTER SETUP COMPLETE
//         ⏳ BACKEND SETUP REQUIRED (Follow MIDTRANS_SETUP_BACKEND.dart)
