import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
import 'DetailNavigasiPage.dart';
import '../../../core/widgets/badge_icon.dart';
import '../notification/notification_screen.dart';
import '../../../core/services/badge_service.dart';

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

    // Update status dan lokasi ke backend Laravel
    try {
      double lat = 0.0;
      double lng = 0.0;
      if (value) {
        // Cek dan ambil GPS saat online
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            lat = position.latitude;
            lng = position.longitude;
          }
        }
      }

      await http.post(
        Uri.parse('$apiUrl/kurir/update-location'),
        body: {
          'latitude': lat.toString(),
          'longitude': lng.toString(),
          'is_online': value ? '1' : '0',
        },
      );
    } catch (e) {
      debugPrint("Gagal update status online ke server: $e");
    }

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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 16.0),
              child: ValueListenableBuilder<BadgeCounts>(
                valueListenable: BadgeService.counts,
                builder: (context, counts, child) {
                  return BadgeIcon(
                    icon: Icons.notifications_none,
                    color: Colors.black,
                    count: counts.notif,
                  );
                },
              ),
            ),
          ),
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

  // WIDGET KARTU TUGAS (DILENGKAPI BADGE TIPE & PEMBAYARAN JELAS)
  Widget _buildTugasCard(Map<String, dynamic> tugas) {
    String status = tugas['status'] ?? '';
    final s = status.toLowerCase();
    bool isMenunggu = status == 'Menunggu Kurir' || status == 'Menunggu Konfirmasi';
    bool isJemput = s.contains('konfirmasi') ||
        s.contains('kurir') ||
        s.contains('jemput') ||
        s.contains('menuju lokasi') ||
        s.contains('tiba di lokasi');
    bool isDiLaundry = s.contains('diterima laundry') ||
        s.contains('cuci') ||
        s.contains('pembayaran');
    bool isAntar = s.contains('siap') || s.contains('antar');

    // Pembayaran
    final String paymentMethod = (tugas['payment_method'] ?? '').toString().toLowerCase();
    final String paymentStatus = (tugas['payment_status'] ?? '').toString().toLowerCase();
    final bool isCod = paymentMethod == 'cod';
    final bool isPaid = paymentStatus == 'paid' ||
        paymentStatus == 'paid_cod' ||
        paymentStatus == 'cod_confirmed' ||
        paymentStatus == 'settlement' ||
        paymentStatus == 'capture';
    final int totalHarga = (double.tryParse(tugas['total_harga']?.toString() ?? '0') ?? 0).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isJemput
              ? Colors.orange.shade200
              : isAntar
                  ? Colors.blue.shade200
                  : Colors.grey.shade200,
          width: (isJemput || isAntar) ? 1.2 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge Tipe Tugas + ID Pesanan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isJemput
                      ? Colors.orange.shade50
                      : isDiLaundry
                          ? Colors.purple.shade50
                          : isAntar
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isJemput
                          ? Icons.shopping_bag_outlined
                          : isDiLaundry
                              ? Icons.local_laundry_service
                              : isAntar
                                  ? Icons.delivery_dining
                                  : Icons.check_circle_outline,
                      size: 14,
                      color: isJemput
                          ? Colors.orange.shade800
                          : isDiLaundry
                              ? Colors.purple.shade800
                              : isAntar
                                  ? Colors.blue.shade800
                                  : Colors.green.shade800,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isJemput
                          ? 'JEMPUT CUCIAN'
                          : isDiLaundry
                              ? 'PROSES CUCI DI TOKO'
                              : isAntar
                                  ? 'ANTAR CUCIAN BERSIH'
                                  : 'SELESAI',
                      style: TextStyle(
                        color: isJemput
                            ? Colors.orange.shade800
                            : isDiLaundry
                                ? Colors.purple.shade800
                                : isAntar
                                    ? Colors.blue.shade800
                                    : Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 12),

          // Alamat Pelanggan
          const Text(
            'Alamat Pelanggan',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            tugas['alamat'] ?? 'Alamat tidak tersedia',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),

          // Nama Pelanggan + Badge Tagihan COD / Lunas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    tugas['nama_pelanggan'] ?? 'Pelanggan',
                    style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isCod && !isPaid)
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isCod && !isPaid)
                        ? const Color(0xFFFFB74D)
                        : const Color(0xFF81C784),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (isCod && !isPaid) ? Icons.payments_outlined : Icons.check_circle_outline,
                      size: 12,
                      color: (isCod && !isPaid) ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (isCod && !isPaid)
                          ? 'Tagih COD: Rp ${NumberFormat('#,###', 'id_ID').format(totalHarga)}'
                          : 'Lunas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (isCod && !isPaid) ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // TOMBOL AKSI
          if (isMenunggu)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _terimaTugas(tugas['id'].toString()),
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: const Text(
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
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailNavigasiPage(tugas: tugas),
                    ),
                  );

                  if (result == true) {
                    _fetchTugasAktif();
                  }
                },
                icon: const Icon(Icons.navigation_outlined, color: AppColors.primary, size: 18),
                label: const Text(
                  'Buka Detail Navigasi & Status',
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

