import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
import 'DetailNavigasiPage.dart';

class CourierHistoryTab extends StatefulWidget {
  const CourierHistoryTab({super.key});

  @override
  State<CourierHistoryTab> createState() => _CourierHistoryTabState();
}

class _CourierHistoryTabState extends State<CourierHistoryTab> {
  bool isLoading = true;
  bool isLocaleReady = false;
  List<dynamic> listTugas = [];
  String searchQuery = "";
  String activeTab = "Semua"; // Pilihan: 'Semua', 'Jemput', 'Antar', 'Selesai'

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() => isLocaleReady = true);
        _fetchHistory();
      }
    });
  }

  Future<void> _fetchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String idKurir = prefs.getString('user_id') ?? "";

    if (idKurir.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/kurir/tugas/$idKurir'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            listTugas = [...(data['aktif'] ?? []), ...(data['riwayat'] ?? [])];
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Gagal mengambil riwayat: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- LOGIKA FILTER TAB & PENCARIAN CERDAS ---
  List<dynamic> get filteredTugas {
    return listTugas.where((p) {
      String idOrder = (p['id_pesanan'] ?? p['id']?.toString() ?? '').toLowerCase();
      String namaPelanggan = (p['nama_pelanggan'] ?? '').toLowerCase();
      String alamat = (p['alamat'] ?? '').toLowerCase();
      String status = (p['status'] ?? '').toLowerCase();

      bool matchSearch = idOrder.contains(searchQuery.toLowerCase()) ||
          namaPelanggan.contains(searchQuery.toLowerCase()) ||
          alamat.contains(searchQuery.toLowerCase());

      bool matchTab = true;
      if (activeTab == 'Jemput') {
        // Tugas fase penjemputan
        matchTab = status.contains('konfirmasi') ||
            status.contains('kurir') ||
            status.contains('jemput') ||
            status.contains('menuju lokasi') ||
            status.contains('tiba di lokasi');
      } else if (activeTab == 'Antar') {
        // Tugas fase pengantaran
        matchTab = status.contains('siap') || status.contains('antar');
      } else if (activeTab == 'Selesai') {
        matchTab = status == 'selesai';
      }

      return matchSearch && matchTab;
    }).toList();
  }

  Color _getStatusColor(String status) {
    String s = status.toLowerCase();
    if (s.contains('selesai')) return Colors.green;
    if (s.contains('siap') || s.contains('antar')) return Colors.blue;
    if (s.contains('cuci') || s.contains('diterima')) return Colors.purple;
    if (s.contains('menunggu') || s.contains('jemput') || s.contains('tiba')) return Colors.orange;
    if (s.contains('batal')) return Colors.red;
    return Colors.grey;
  }

  IconData _getServiceIcon(String layanan) {
    String l = layanan.toLowerCase();
    if (l.contains('kering')) return Icons.local_laundry_service;
    if (l.contains('setrika')) return Icons.iron;
    if (l.contains('kilat')) return Icons.bolt;
    return Icons.local_shipping;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Riwayat Tugas',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0.5,
      ),
      body: isLoading || !isLocaleReady
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                _buildHeaderBar(),
                Expanded(
                  child: filteredTugas.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _fetchHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            itemCount: filteredTugas.length,
                            itemBuilder: (context, index) {
                              return _buildTaskCard(filteredTugas[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari ID, pelanggan, atau alamat...',
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tab Filter: Semua, Jemput, Antar, Selesai
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', Icons.all_inbox_rounded),
                _buildFilterChip('Jemput', Icons.shopping_bag_outlined),
                _buildFilterChip('Antar', Icons.delivery_dining_rounded),
                _buildFilterChip('Selesai', Icons.check_circle_outline_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String tab, IconData icon) {
    bool isSelected = activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => activeTab = tab),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              tab,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    String status = task['status'] ?? 'Proses';
    String idOrder = task['id_pesanan'] ?? '-';
    String layanan = task['layanan'] ?? 'Layanan Laundry';
    String pelanggan = task['nama_pelanggan'] ?? 'Pelanggan';
    String alamat = task['alamat'] ?? '-';

    // Deteksi Tipe Tugas
    final s = status.toLowerCase();
    final bool isJemput = s.contains('konfirmasi') ||
        s.contains('kurir') ||
        s.contains('jemput') ||
        s.contains('menuju lokasi') ||
        s.contains('tiba di lokasi');
    final bool isDiLaundry = s.contains('diterima laundry') ||
        s.contains('cuci') ||
        s.contains('pembayaran');
    final bool isAntar = s.contains('siap') || s.contains('antar');
    final bool isSelesai = s == 'selesai';

    // Deteksi Pembayaran COD vs Lunas
    final String paymentMethod = (task['payment_method'] ?? '').toString().toLowerCase();
    final String paymentStatus = (task['payment_status'] ?? '').toString().toLowerCase();
    final bool isCod = paymentMethod == 'cod';
    final bool isPaid = paymentStatus == 'paid' ||
        paymentStatus == 'paid_cod' ||
        paymentStatus == 'cod_confirmed' ||
        paymentStatus == 'settlement' ||
        paymentStatus == 'capture';
    final int totalHarga = (double.tryParse(task['total_harga']?.toString() ?? '0') ?? 0).toInt();

    // Format Tanggal
    String dateStr = '-';
    try {
      if (task['created_at'] != null) {
        dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(task['created_at']));
      }
    } catch (_) {
      dateStr = task['created_at'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isJemput
              ? Colors.orange.shade200
              : isAntar
                  ? Colors.blue.shade200
                  : Colors.grey.shade200,
          width: (isJemput || isAntar) ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris 1: TIPE TUGAS + STATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Tipe Tugas (JEMPUT vs ANTAR vs PROSES CUCI)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isJemput
                      ? Colors.orange.shade50
                      : isDiLaundry
                          ? Colors.purple.shade50
                          : isAntar
                              ? Colors.blue.shade50
                              : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
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
                      size: 13,
                      color: isJemput
                          ? Colors.orange.shade800
                          : isDiLaundry
                              ? Colors.purple.shade800
                              : isAntar
                                  ? Colors.blue.shade800
                                  : Colors.green.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isJemput
                          ? 'JEMPUT PAKAIAN'
                          : isDiLaundry
                              ? 'PROSES CUCI TOKO'
                              : isAntar
                                  ? 'ANTAR PAKAIAN'
                                  : 'SELESAI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isJemput
                            ? Colors.orange.shade800
                            : isDiLaundry
                                ? Colors.purple.shade800
                                : isAntar
                                    ? Colors.blue.shade800
                                    : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Status Alur Saat Ini
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Baris 2: Ikon Layanan + Info Pesanan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1FAFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getServiceIcon(layanan),
                  color: const Color(0xFF00A2E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layanan,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$idOrder • $pelanggan',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alamat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Baris 3: BADGE PEMBAYARAN (COD vs LUNAS) + TANGGAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Pembayaran
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
                          : 'Lunas (Non-Tunai)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (isCod && !isPaid) ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
          const Divider(height: 20),

          // Footer: Status Deskripsi + Tombol Detail Navigasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSelesai ? Icons.check_circle : Icons.radio_button_checked,
                    color: _getStatusColor(status),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSelesai
                        ? 'Tugas Selesai'
                        : isDiLaundry
                            ? 'Menunggu cuci di toko'
                            : isAntar
                                ? 'Siap diantar ke rumah'
                                : 'Siap dijemput',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailNavigasiPage(tugas: task),
                    ),
                  );
                  if (result == true) {
                    _fetchHistory();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2E9).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Navigasi & Detail',
                        style: TextStyle(
                          color: Color(0xFF00A2E9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Color(0xFF00A2E9),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 70,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada pesanan di kategori "$activeTab"',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}