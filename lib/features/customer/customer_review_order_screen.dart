import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import 'customer_order_screen.dart';
import '../../../core/services/api_config.dart';

class CustomerReviewOrderScreen extends StatefulWidget {
  final String layanan;
  final double berat;
  final int totalHarga;
  final String catatan;
  final String alamat;
  final String latitude;
  final String longitude;
  final DateTime tanggal;
  final String waktu;
  final int ongkir; // Biaya flat jemput & antar
  final String packageId;

  const CustomerReviewOrderScreen({
    super.key,
    required this.layanan,
    required this.berat,
    required this.totalHarga,
    required this.catatan,
    required this.alamat,
    required this.latitude,
    required this.longitude,
    required this.tanggal,
    required this.waktu,
    required this.ongkir,
    this.packageId = '',
  });

  @override
  State<CustomerReviewOrderScreen> createState() =>
      _CustomerReviewOrderScreenState();
}

class _CustomerReviewOrderScreenState extends State<CustomerReviewOrderScreen> {
  bool isLoading = false;
  bool isCheckingPromo = false;
  final TextEditingController _promoController = TextEditingController();
  Map<String, dynamic>? selectedPromo;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _terapkanPromo() async {
    if (_promoController.text.trim().isEmpty) return;

    setState(() {
      isCheckingPromo = true;
      selectedPromo = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$apiUrl/promo/check'),
        headers: {'Accept': 'application/json'},
        body: {'kode_promo': _promoController.text.trim()},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          selectedPromo = data['data'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
          );
        }
      } else {
        final error = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error['message'] ?? 'Promo tidak valid'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isCheckingPromo = false);
    }
  }

  int get subtotal => widget.totalHarga - widget.ongkir;
  int get hargaPerKg =>
      widget.berat > 0 ? (subtotal / widget.berat).round() : 0;
  
  int get totalDiskon {
    if (selectedPromo == null) return 0;
    int diskon = 0;
    final int nilai = selectedPromo!['nilai_diskon'] ?? 0;
    if (selectedPromo!['tipe_diskon'] == 'persen') {
      diskon = (subtotal * nilai / 100).round();
    } else {
      diskon = nilai;
    }
    // Maksimal diskon tidak melebihi subtotal
    return diskon > subtotal ? subtotal : diskon;
  }

  int get grandTotal => subtotal + widget.ongkir - totalDiskon;

  String get apiUrl => apiBaseUrl;

  IconData _getIconData(String namaLayanan) {
    String name = namaLayanan.toLowerCase();
    if (name.contains('kering')) return Icons.air;
    if (name.contains('setrika')) return Icons.iron_outlined;
    if (name.contains('kilat')) return Icons.bolt;
    if (name.contains('sepatu')) return Icons.pets;
    return Icons.checkroom_outlined;
  }

  // --- PERBAIKAN LOGIKA PENGIRIMAN DATA KE LARAVEL ---
  Future<void> _lanjutKonfirmasiPenjemputan() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Pastikan User ID selalu ada. Jika tidak, kirim '1' sebagai default (untuk testing)
    String userId = prefs.getString('user_id') ?? "1";

    try {
      // Print ini sangat berguna untuk melihat apakah data yang dikirim Flutter sudah benar
      debugPrint("MENGIRIM DATA KE LARAVEL: $apiUrl/pesanan/buat");

      final response = await http.post(
        Uri.parse('$apiUrl/pesanan/buat'),
        headers: {
          'Accept':
              'application/json', // Wajib ada agar Laravel membalas error detail
        },
        body: {
          'user_id': userId,
          'layanan': widget.layanan,
          'berat': widget.berat.toString(),
          'berat_estimasi': widget.berat.toString(),
          'total_harga': grandTotal.toString(), // Harga estimasi dikurangi diskon
          'promo_id': selectedPromo != null ? selectedPromo!['id'].toString() : '',
          'total_diskon': totalDiskon.toString(),
          'catatan': widget.catatan.isEmpty
              ? "-"
              : widget
                    .catatan, // Jangan biarkan null jika di database tidak boleh null
          'alamat_jemput': widget.alamat,
          'latitude': widget.latitude,
          'longitude': widget.longitude,
          'tanggal_jemput': DateFormat('yyyy-MM-dd').format(widget.tanggal),
          'waktu_jemput': widget.waktu,
          'package_id': widget.packageId,
        },
      );

      // Cek apakah Laravel membalas Sukses
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pesanan berhasil dibuat! Menunggu kurir menjemput.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Pindah ke Tab Pesanan (Riwayat)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const CustomerOrderScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        // Jika Laravel menolak, tampilkan pesan error dari Laravel di Terminal Flutter!
        debugPrint("LARAVEL ERROR: ${response.statusCode} - ${response.body}");
        throw Exception("Gagal API");
      }
    } catch (e) {
      debugPrint("FLUTTER ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal membuat pesanan. Pastikan server Laravel menyala.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konfirmasi Pesanan',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Periksa kembali pesanan Anda',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -5),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- PEMBERITAHUAN BAHWA INI HANYA ESTIMASI ---
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total harga pasti akan muncul setelah cucian ditimbang oleh Admin di toko.',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimasi Sementara',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(widget.totalHarga)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: isLoading ? null : _lanjutKonfirmasiPenjemputan,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Buat Pesanan & Jemput',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- KARTU 1: DETAIL LAYANAN ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Detail Layanan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1FAFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconData(widget.layanan),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.layanan,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Est. Pengerjaan 2-3 hari',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimasi Berat',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        '${widget.berat % 1 == 0 ? widget.berat.toInt() : widget.berat} kg',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Harga per kg',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(hargaPerKg)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // --- KARTU 2: LOKASI & JADWAL ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Lokasi & Jadwal Penjemputan',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alamat',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.alamat,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tanggal',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'E, d MMM',
                                  'id_ID',
                                ).format(widget.tanggal),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jam',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.waktu,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // --- KARTU 3: RINCIAN BIAYA ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Estimasi Rincian Biaya',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal (${widget.berat % 1 == 0 ? widget.berat.toInt() : widget.berat} kg x Rp ${NumberFormat('#,###', 'id_ID').format(hargaPerKg)})',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ongkos Jemput & Antar (Flat)',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(widget.ongkir)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (totalDiskon > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Diskon Promo',
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                        Text(
                          '- Rp ${NumberFormat('#,###', 'id_ID').format(totalDiskon)}',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(grandTotal)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- KARTU PROMO ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.local_offer_outlined, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Gunakan Promo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan kode promo',
                            hintStyle: const TextStyle(fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isCheckingPromo ? null : _terapkanPromo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: isCheckingPromo
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Terapkan', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  if (selectedPromo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            'Promo ${selectedPromo!['judul']} berhasil diterapkan!',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
