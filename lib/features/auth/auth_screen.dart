import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/api_config.dart';
import '../../core/services/firebase_service.dart';
import '../courier/courier_login.dart';
// --- IMPORT WADAH UTAMA KITA ---
import '../customer/customer_home.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // --- LOGIKA PINTAR ALAMAT API ---
  String get apiUrl => apiBaseUrl;

  final TextEditingController _loginIdentifierController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regConfirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loginProses() async {
    if (_loginIdentifierController.text.isEmpty ||
        _loginPasswordController.text.isEmpty) {
      _showPesan('Harap isi email/no. HP dan kata sandi!');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': _loginIdentifierController.text,
          'password': _loginPasswordController.text,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // =======================================================
        // LOGIKA PENCEGAHAN: CEK ROLE SEBELUM MENYIMPAN DATA
        // =======================================================
        String userRole = responseData['data']['role'].toString().toLowerCase();

        if (userRole == 'kurir' || userRole == 'mitra') {
          // JIKA YANG LOGIN ADALAH KURIR, TOLAK DAN TAMPILKAN PESAN
          _showPesan(
            'Akun ini terdaftar sebagai Mitra Kurir. Silakan gunakan menu "Masuk sebagai Kurir" di bawah.',
            isSukses: false,
          );
          setState(() => isLoading = false);
          return; // Hentikan proses di sini, jangan simpan data ke memori
        }

        // JIKA BUKAN KURIR (Berarti Pelanggan Biasa), LANJUT SIMPAN DATA
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final userId = responseData['data']['id'].toString();
        await prefs.setString('user_id', userId);
        await prefs.setString('token', responseData['access_token']);
        await prefs.setString('user_name', responseData['data']['name']);
        await prefs.setString('user_role', responseData['data']['role']);

        // --- SETUP FCM TOKEN & KIRIM KE BACKEND ---
        String? fcmToken = await FirebaseService().setupFCM();
        if (fcmToken != null) {
          try {
            await http.post(
              Uri.parse('$apiUrl/profil/update-fcm/$userId'),
              headers: {'Accept': 'application/json'},
              body: {'fcm_token': fcmToken},
            );
          } catch (e) {
            debugPrint("Error sending FCM Token: $e");
          }
        }

        _showPesan(
          'Login Berhasil! Selamat Datang, ${responseData['data']['name']}',
          isSukses: true,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
          );
        }
      } else {
        _showPesan(
          responseData['message'] ?? 'Login gagal. Periksa kembali data Anda.',
        );
      }
    } catch (e) {
      _showPesan('Terjadi kesalahan koneksi ke server Laravel/MySQL.');
      debugPrint("Error Login: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _registerProses() async {
    if (_regNameController.text.isEmpty ||
        _regEmailController.text.isEmpty ||
        _regPasswordController.text.isEmpty) {
      _showPesan('Harap lengkapi semua data pendaftaran!');
      return;
    }
    if (_regPasswordController.text != _regConfirmPasswordController.text) {
      _showPesan('Konfirmasi kata sandi tidak cocok!');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/register'),
        headers: {'Accept': 'application/json'},
        body: {
          'name': _regNameController.text,
          'no_hp': _regPhoneController.text,
          'email': _regEmailController.text,
          'password': _regPasswordController.text,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        _showPesan('Pendaftaran Berhasil! Silakan masuk.', isSukses: true);

        _regNameController.clear();
        _regPhoneController.clear();
        _regEmailController.clear();
        _regPasswordController.clear();
        _regConfirmPasswordController.clear();

        setState(() => isLogin = true);
      } else {
        if (responseData['error'] != null) {
          String errorMsg = "";
          responseData['error'].forEach((key, value) {
            errorMsg += "${value[0]}\n";
          });
          _showPesan(errorMsg.trim());
        } else {
          _showPesan('Pendaftaran gagal. Silakan coba lagi.');
        }
      }
    } catch (e) {
      _showPesan('Terjadi kesalahan koneksi ke server Laravel/MySQL.');
      debugPrint("Error Register: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showPesan(String pesan, {bool isSukses = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isSukses ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 60,
                left: 30,
                right: 30,
                bottom: 40,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Pint Point Laundry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(
                    isLogin ? 'Selamat Datang Kembali!' : 'Buat Akun Baru',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isLogin
                        ? 'Masuk untuk melanjutkan pesanan laundry Anda'
                        : 'Daftar untuk mulai menggunakan layanan kami',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isLogin = true),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLogin
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Masuk',
                                  style: TextStyle(
                                    color: isLogin
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isLogin = false),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !isLogin
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Daftar',
                                  style: TextStyle(
                                    color: !isLogin
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    isLogin ? _buildLoginForm() : _buildRegisterForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          'Email',
          'contoh@email.com',
          false,
          _loginIdentifierController,
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kata Sandi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _loginPasswordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: 'Masukkan kata sandi',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'Lupa Kata Sandi?',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: isLoading ? null : _loginProses,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Masuk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 30),
        Center(
          child: Column(
            children: [
              const Text(
                'Anda Mitra Kurir Pint Point?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CourierLoginScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Masuk sebagai Kurir',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Nama Lengkap', 'John Doe', false, _regNameController),
        const SizedBox(height: 15),
        _buildTextField(
          'Nomor WhatsApp',
          '08123456789',
          false,
          _regPhoneController,
        ),
        const SizedBox(height: 15),
        _buildTextField(
          'Email',
          'contoh@email.com',
          false,
          _regEmailController,
        ),
        const SizedBox(height: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kata Sandi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regPasswordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                hintText: 'Min. 8 karakter',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Konfirmasi Kata Sandi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regConfirmPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Ulangi kata sandi',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureConfirmPassword = !obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: isLoading ? null : _registerProses,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Daftar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    bool isPassword,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: false,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
