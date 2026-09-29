import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
// Pastikan path import DetailNavigasiPage benar
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
  String activeTab = "Semua";

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

  // --- LOGIKA AMBIL DATA (Sama dengan RiwayatTab) ---
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
            // Menggabungkan data Aktif dan Riwayat agar bisa di-filter di Tab "Semua"
            listTugas = [...(data['aktif'] ?? []), ...(data['riwayat'] ?? [])];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil riwayat: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- LOGIKA FILTER TAB & SEARCH ---
  List<dynamic> get filteredTugas {
    return listTugas.where((p) {
      String idOrder = (p['id_pesanan'] ?? p['id']?.toString() ?? '')
          .toLowerCase();
      String namaPelanggan = (p['nama_pelanggan'] ?? '').toLowerCase();
      String status = (p['status'] ?? '').toLowerCase();

      bool matchSearch =
          idOrder.contains(searchQuery.toLowerCase()) ||
          namaPelanggan.contains(searchQuery.toLowerCase());

      bool matchTab = true;
      if (activeTab == 'Aktif') {
        // Status selain Selesai atau Batal dianggap Aktif
        matchTab = status != 'selesai' && status != 'batal';
      } else if (activeTab == 'Selesai') {
        matchTab = status == 'selesai';
      }

      return matchSearch && matchTab;
    }).toList();
  }

  Color _getStatusColor(String status) {
    String s = status.toLowerCase();
    if (s.contains('menunggu')) return Colors.orange;
    if (s.contains('dijemput') || s.contains('menuju') || s.contains('diantar')) {
      return Colors.blue;
    }
    if (s.contains('selesai')) return Colors.green;
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
      backgroundColor: Colors.white,
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
        elevation: 0,
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
                              horizontal: 20,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari ID pesanan atau pelanggan...',
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: ['Semua', 'Aktif', 'Selesai'].map((tab) {
              bool isSelected = activeTab == tab;
              return GestureDetector(
                onTap: () => setState(() => activeTab = tab),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00A2E9)
                        : const Color(0xFFF4F6F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    String status = task['status'] ?? 'Proses';
    String idOrder = task['id_pesanan'] ?? '-';
    String layanan = task['layanan'] ?? 'Layanan Laundry';
    String pelanggan = task['nama_pelanggan'] ?? 'Pelanggan';

    // Format Tanggal
    String dateStr = '-';
    try {
      if (task['created_at'] != null) {
        dateStr = DateFormat(
          'dd MMM yyyy',
          'id_ID',
        ).format(DateTime.parse(task['created_at']));
      }
    } catch (e) {
      dateStr = task['created_at'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            layanan,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
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
                    const SizedBox(height: 5),
                    Text(
                      '$idOrder • $pelanggan',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    status.toLowerCase() == 'selesai'
                        ? Icons.check_circle
                        : Icons.radio_button_checked,
                    color: _getStatusColor(status),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status.toLowerCase() == 'selesai'
                        ? 'Tugas telah selesai'
                        : 'Tugas sedang berjalan',
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // --- TOMBOL DETAIL AKTIF ---
              GestureDetector(
                onTap: () async {
                  // Jika tugas masih aktif, kurir bisa masuk lagi ke navigasi
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailNavigasiPage(tugas: task),
                    ),
                  );
                  if (result == true) {
                    _fetchHistory(); // Refresh jika ada perubahan status
                  }
                },
                child: const Row(
                  children: [
                    Text(
                      'Detail',
                      style: TextStyle(
                        color: Color(0xFF00A2E9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF00A2E9),
                    ),
                  ],
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
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          const Text(
            'Tugas tidak ditemukan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Text(
            'Coba ubah filter atau kata kunci pencarian.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
