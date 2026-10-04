import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/firebase_service.dart';
import 'courier_home_screen.dart';

class CourierLoginScreen extends StatefulWidget {
  const CourierLoginScreen({super.key});

  @override
  State<CourierLoginScreen> createState() => _CourierLoginScreenState();
}

class _CourierLoginScreenState extends State<CourierLoginScreen> {
  bool obscurePassword = true;
  bool isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String get apiUrl => apiBaseUrl;

  // --- FUNGSI LOGIN KHUSUS KURIR ---
  Future<void> _loginKurir() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showPesan('Email dan Kata Sandi wajib diisi!');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/login'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        String userRole = responseData['data']['role'].toString().toLowerCase();

        // CEK APAKAH YANG LOGIN BENAR-BENAR KURIR
        if (userRole == 'kurir' || userRole == 'mitra') {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final userId = responseData['data']['id'].toString();
          await prefs.setString('user_id', userId);
          await prefs.setString('token', responseData['access_token']);
          await prefs.setString('user_name', responseData['data']['name']);
          await prefs.setString('user_role', responseData['data']['role']);

          // --- SETUP FCM TOKEN & KIRIM KE BACKEND ---
          String? fcmToken = await AppFirebaseService().setupFCM();
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

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CourierHomeScreen(),
              ),
            );
          }
        } else {
          // Jika pelanggan/admin mencoba masuk lewat portal ini
          _showPesan(
            'Akses Ditolak! Akun Anda bukan terdaftar sebagai Mitra Kurir.',
          );
        }
      } else {
        _showPesan(responseData['message'] ?? 'Email atau sandi salah.');
      }
    } catch (e) {
      _showPesan('Gagal terhubung ke server Laravel.');
      debugPrint("Error Login Kurir: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showPesan(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 280,
                  padding: const EdgeInsets.only(top: 60, left: 25, right: 25),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Icon(
                            Icons.water_drop_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Pint Point Laundry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                      const Text(
                        'Portal Mitra Kurir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masuk menggunakan kredensial akun yang telah didaftarkan oleh Admin.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: -25,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
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
                    alignment: Alignment.center,
                    child: const Text(
                      'Masuk (Khusus Kurir)',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    'Email Kurir',
                    'contoh: kurir_budi@pintpoint.com',
                    false,
                    _emailController,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    'Kata Sandi',
                    'Masukkan kata sandi',
                    true,
                    _passwordController,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          _showPesan('Hubungi Admin untuk mereset kata sandi.'),
                      child: const Text(
                        'Lupa Kata Sandi?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading ? null : _loginKurir,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
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
          style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? obscurePassword : false,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.textLight,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textLight,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

