import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// IMPORT IMAGE PICKER
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import 'courier_login.dart';
import '../../../core/services/api_config.dart';
import 'courier_settings_screens.dart'; // <-- IMPORT HALAMAN PENGATURAN BARU

class CourierAccountTab extends StatefulWidget {
  const CourierAccountTab({super.key});

  @override
  State<CourierAccountTab> createState() => _CourierAccountTabState();
}

class _CourierAccountTabState extends State<CourierAccountTab> {
  bool isLoading = true;
  String idKurir = "";
  String namaKurir = "Memuat...";
  String emailKurir = "Memuat...";
  String? fotoUrl;

  final ImagePicker _picker = ImagePicker();

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfil();
  }

  // --- AMBIL DATA DARI LARAVEL ---
  Future<void> _fetchProfil() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    idKurir = prefs.getString('user_id') ?? "";

    if (idKurir.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/kurir/profil/$idKurir'),
      );
      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          setState(() {
            namaKurir = res['data']['name'];
            emailKurir = res['data']['email'];
            fotoUrl = res['data']['foto_url'];
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load profil: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- LOGIKA UPLOAD FOTO PROFIL ---
  Future<void> _pickAndUploadImage() async {
    try {
      // Buka galeri HP
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );

      if (pickedFile != null) {
        setState(() => isLoading = true); // Tampilkan loading

        // Siapkan pengiriman file (Multipart Request)
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiUrl/kurir/profil/foto/$idKurir'),
        );

        // Tambahkan file ke request
        request.files.add(
          await http.MultipartFile.fromPath('foto', pickedFile.path),
        );

        // Kirim ke Laravel
        var response = await request.send();
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);

        if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
          setState(() {
            fotoUrl = jsonResponse['foto_url']; // Update foto di layar seketika
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto Profil berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception("Gagal unggah");
        }
      }
    } catch (e) {
      debugPrint("Error upload: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengunggah foto.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- FUNGSI LOGOUT ---
  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi kurir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CourierLoginScreen(),
                  ),
                );
              }
            },
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // --- BAGIAN ATAS: FOTO PROFIL & NAMA ---
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUploadImage, // JIKA FOTO/KAMERA DIKLIK
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                    width: 4,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  // Tampilkan foto dari database, jika null tampilkan ikon default
                                  backgroundImage: fotoUrl != null
                                      ? NetworkImage(fotoUrl!)
                                      : null,
                                  child: fotoUrl == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          namaKurir,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Mitra Aktif Pint Point',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emailKurir,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- BAGIAN TENGAH: MENU PENGATURAN (Bisa di-klik!) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pengaturan Akun',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildMenuOption(
                                Icons.person_outline,
                                'Edit Profil Informasi',
                                () async {
                                  bool? updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CourierEditProfileScreen(),
                                    ),
                                  );
                                  if (updated == true) _fetchProfil();
                                },
                              ),
                              const Divider(
                                height: 1,
                                indent: 50,
                                endIndent: 20,
                              ),
                              _buildMenuOption(
                                Icons.motorcycle_outlined,
                                'Kendaraan & Pelat Nomor',
                                () async {
                                  bool? updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CourierVehicleScreen(),
                                    ),
                                  );
                                  if (updated == true) _fetchProfil();
                                },
                              ),
                              const Divider(
                                height: 1,
                                indent: 50,
                                endIndent: 20,
                              ),
                              _buildMenuOption(
                                Icons.notifications_none,
                                'Pengaturan Notifikasi',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CourierNotifScreen(),
                                    ),
                                  );
                                },
                              ),
                              const Divider(
                                height: 1,
                                indent: 50,
                                endIndent: 20,
                              ),
                              _buildMenuOption(
                                Icons.help_outline,
                                'Pusat Bantuan',
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CourierHelpScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // --- BAGIAN BAWAH: TOMBOL LOGOUT ---
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withOpacity(
                                0.1,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Keluar dari Akun',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: _logout,
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap, // AKSI KLIK AKTIF
    );
  }
}
