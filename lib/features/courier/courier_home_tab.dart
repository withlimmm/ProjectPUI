import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
import 'DetailNavigasiPage.dart';

class CourierHomeTab extends StatefulWidget {
  const CourierHomeTab({super.key});

  @override
  State<CourierHomeTab> createState() => _CourierHomeTabState();
}

class _CourierHomeTabState extends State<CourierHomeTab> {
  String namaKurir = "Memuat...";
  String idKurir = "";
  bool isOnline = false;
  bool isLoading = false;

  List<dynamic> listTugasAktif = [];
  int totalTugasSelesai = 0; // Bisa diupdate nanti dari API riwayat

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadDataAwal();
  }

  // --- 1. AMBIL DATA DARI MEMORI LOKAL ---
  Future<void> _loadDataAwal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      namaKurir = prefs.getString('user_name') ?? "Kurir";
      idKurir = prefs.getString('user_id') ?? "";
      isOnline = prefs.getBool('is_online') ?? false;
    });

    if (isOnline) {
      _fetchTugasAktif();
    }
  }

  // --- 2. SWITCH ONLINE / OFFLINE ---
  Future<void> _toggleStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_online', value);

    setState(() {
      isOnline = value;
      if (!isOnline) {
        listTugasAktif.clear(); // Bersihkan layar jika offline
      }
    });

    if (isOnline) {
      _fetchTugasAktif(); // Tarik data jika online
    }
  }

  // --- 3. AMBIL DAFTAR TUGAS DARI LARAVEL (ANTI INFINITE LOADING) ---
  Future<void> _fetchTugasAktif() async {
    if (idKurir.isEmpty || !isOnline) return;

    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/kurir/tugas/$idKurir'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            listTugasAktif = data['aktif'] ?? [];
            isLoading = false;
          });
        }
      } else {
        debugPrint("Error dari Server: ${response.statusCode}");
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Gagal tarik tugas: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 4. FUNGSI KURIR TERIMA TUGAS ---
  Future<void> _terimaTugas(String orderId) async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Menerima tugas...')));

      final response = await http.post(
        Uri.parse(
          '$apiUrl/kurir/terima-tugas/$orderId',
        ), // URL disesuaikan dengan routes Laravel terbaru
        body: {'kurir_id': idKurir},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tugas berhasil diterima!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTugasAktif(); // Refresh daftar tugas
      } else {
        throw Exception("Gagal terima tugas");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan jaringan.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, $namaKurir!',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              isOnline ? 'Kamu sedang online' : 'Kamu sedang offline',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: isOnline,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey.shade400,
                onChanged: _toggleStatus,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTugasAktif,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- KOTAK BIRU TOTAL TUGAS ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A2E9), Color(0xFF5B61F4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      totalTugasSelesai.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Total Tugas Diselesaikan',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Text(
                'Tugas Aktif Saat Ini',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // --- LOGIKA TAMPILAN TUGAS ---
              if (!isOnline)
                _buildOfflineState()
              else if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (listTugasAktif.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listTugasAktif.length,
                  itemBuilder: (context, index) {
                    return _buildTugasCard(listTugasAktif[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET KETIKA OFFLINE
  Widget _buildOfflineState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(
              Icons.nightlight_round,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Anda Sedang Offline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Aktifkan status Online di kanan atas\nuntuk mulai menerima orderan jemput/antar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET KETIKA ONLINE TAPI KOSONG
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 100,
              color: Colors.green.shade200,
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Tugas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tetap stand by! Orderan baru akan\nmuncul di halaman ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET KARTU TUGAS (MUNCUL JIKA ADA ORDERAN)
  Widget _buildTugasCard(Map<String, dynamic> tugas) {
    bool isMenunggu = tugas['status'] == 'Menunggu Kurir';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isMenunggu
                      ? Colors.orange.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isMenunggu ? 'Jemput Baru' : 'Sedang Berjalan',
                  style: TextStyle(
                    color: isMenunggu ? Colors.orange : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                tugas['id_pesanan'] ?? '-',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Alamat Pelanggan',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            tugas['alamat'] ?? 'Alamat tidak tersedia',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                tugas['nama_pelanggan'] ?? 'Pelanggan',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(height: 1),
          ),

          // TOMBOL AKSI
          if (isMenunggu)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _terimaTugas(tugas['id'].toString()),
                child: const Text(
                  'Terima Tugas Penjemputan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // --- PERBAIKAN: Fungsi OnPressed dihidupkan ---
                onPressed: () async {
                  // Arahkan ke halaman detail pesanan dan tunggu kurir kembali (pop)
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailNavigasiPage(tugas: tugas),
                    ),
                  );

                  // Jika result true (status diubah di dalam DetailNavigasiPage),
                  // maka kita tarik data terbaru dari Laravel.
                  if (result == true) {
                    _fetchTugasAktif();
                  }
                },
                child: const Text(
                  'Lihat Detail Navigasi',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
