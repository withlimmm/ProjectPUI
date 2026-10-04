import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert'; // PENTING: Import harus di atas
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';

String get apiUrl => apiBaseUrl;

// ============================================================================
// 1. HALAMAN KENDARAAN & PELAT NOMOR (Terhubung Database)
// ============================================================================
class CourierVehicleScreen extends StatefulWidget {
  const CourierVehicleScreen({super.key});

  @override
  State<CourierVehicleScreen> createState() => _CourierVehicleScreenState();
}

class _CourierVehicleScreenState extends State<CourierVehicleScreen> {
  bool isLoading = false;
  final TextEditingController _jenisController = TextEditingController();
  final TextEditingController _platController = TextEditingController();
  final TextEditingController _warnaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('user_id') ?? "";
    if (id.isEmpty) return;

    try {
      final res = await http.get(Uri.parse('$apiUrl/kurir/profil/$id'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _jenisController.text = data['kendaraan'] == '-'
              ? ''
              : data['kendaraan'];
          _platController.text = data['plat_nomor'] == '-'
              ? ''
              : data['plat_nomor'];
          _warnaController.text = data['warna_kendaraan'] == '-'
              ? ''
              : data['warna_kendaraan'];
        });
      }
    } catch (e) {
      debugPrint("Error load: $e");
    }
  }

  Future<void> _simpanData() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('user_id') ?? "";

    try {
      final res = await http.post(
        Uri.parse('$apiUrl/kurir/profil/update/$id'),
        body: {
          'kendaraan': _jenisController.text,
          'plat_nomor': _platController.text,
          'warna_kendaraan': _warnaController.text,
        },
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data kendaraan berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Kembali & beri tanda sukses
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Kendaraan Saya',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(
              'Jenis Kendaraan (Misal: Honda Vario)',
              _jenisController,
            ),
            const SizedBox(height: 15),
            _buildInput('Pelat Nomor (Misal: Z 1234 AB)', _platController),
            const SizedBox(height: 15),
            _buildInput('Warna Kendaraan', _warnaController),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading ? null : _simpanData,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF4F6F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ============================================================================
// 2. HALAMAN EDIT PROFIL (Terhubung Database)
// ============================================================================
class CourierEditProfileScreen extends StatefulWidget {
  const CourierEditProfileScreen({super.key});

  @override
  State<CourierEditProfileScreen> createState() =>
      _CourierEditProfileScreenState();
}

class _CourierEditProfileScreenState extends State<CourierEditProfileScreen> {
  bool isLoading = false;
  bool isFetching = true;
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nohpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Menarik data Nama dan No HP dari database
  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('user_id') ?? "";

    if (id.isEmpty) {
      if (mounted) setState(() => isFetching = false);
      return;
    }

    try {
      final res = await http.get(Uri.parse('$apiUrl/kurir/profil/$id'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _namaController.text = data['name'] ?? '';
          // Karena rute getProfil belum mengembalikan no_hp,
          // sementara kita isi dari nama atau memori jika tidak ada.
          // Nanti pastikan di KurirController.php fungsi getProfil menambahkan baris: 'no_hp' => $user->no_hp
        });
      }
    } catch (e) {
      debugPrint("Error load profil: $e");
    } finally {
      if (mounted) setState(() => isFetching = false);
    }
  }

  Future<void> _simpanData() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String id = prefs.getString('user_id') ?? "";

    try {
      final res = await http.post(
        Uri.parse('$apiUrl/kurir/profil/update/$id'),
        body: {'name': _namaController.text, 'no_hp': _nohpController.text},
      );
      if (res.statusCode == 200) {
        await prefs.setString(
          'user_name',
          _namaController.text,
        ); // Update memori lokal
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profil', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: isFetching
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      filled: true,
                      fillColor: const Color(0xFFF4F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _nohpController,
                    decoration: InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      filled: true,
                      fillColor: const Color(0xFFF4F6F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isLoading ? null : _simpanData,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Simpan Profil',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// 3. HALAMAN NOTIFIKASI (Statis / UI Saja)
// ============================================================================
class CourierNotifScreen extends StatelessWidget {
  const CourierNotifScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Notifikasi',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Notifikasi Pesanan Baru'),
            subtitle: const Text('Bunyikan nada saat ada pesanan masuk'),
            value: true,
            activeThumbColor: AppColors.primary,
            onChanged: (val) {},
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Peringatan Pesanan Telat'),
            subtitle: const Text(
              'Ingatkan jika pesanan belum dijemput/diantar',
            ),
            value: true,
            activeThumbColor: AppColors.primary,
            onChanged: (val) {},
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. HALAMAN PUSAT BANTUAN (Statis / UI Saja)
// ============================================================================
class CourierHelpScreen extends StatelessWidget {
  const CourierHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pusat Bantuan',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.support_agent,
              size: 100,
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Butuh Bantuan?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Jika Anda mengalami kendala aplikasi atau masalah dengan pelanggan, silakan hubungi Admin pusat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.chat, color: Colors.white),
              label: const Text(
                'Chat Admin di WhatsApp',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
