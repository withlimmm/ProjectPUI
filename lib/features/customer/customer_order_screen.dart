import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/theme/app_colors.dart';
import 'customer_home.dart';
import 'customer_profile_screen.dart';
import 'customer_payment_screen.dart';
// --- IMPORT HALAMAN PELACAKAN (LIVE TRACKING) ---
import 'customer_tracking_screen.dart';
import '../../../core/services/api_config.dart';

class CustomerOrderScreen extends StatefulWidget {
  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  bool isLoading = true;
  bool isLocaleReady = false;
  List<dynamic> listPesanan = [];

  String searchQuery = "";
  String activeTab = "Semua";
  int totalTransaksi = 0;
  int totalPesanan = 0;

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() {
          isLocaleReady = true;
        });
        _fetchRiwayatPesanan();
      }
    });
  }

  Future<void> _fetchRiwayatPesanan() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? "";

    if (userId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiUrl/pesanan-user/$userId'),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          List<dynamic> data = json.decode(response.body);

          int tempTotalHarga = 0;
          int tempTotalPesanan = 0;

          // --- LOGIKA PERHITUNGAN BARU ---
          for (var item in data) {
            String status = (item['status'] ?? '').toString().toLowerCase();

            // Hanya hitung pesanan yang BUKAN menunggu pembayaran & BUKAN batal.
            if (!status.contains('menunggu') && !status.contains('batal')) {
              int hargaPesanan =
                  (double.tryParse(item['total_harga']?.toString() ?? '0') ?? 0)
                      .toInt();

              tempTotalHarga += hargaPesanan; // Tambahkan uangnya
              tempTotalPesanan++; // Tambahkan jumlah pesanannya
            }
          }

          setState(() {
            listPesanan = data;
            totalPesanan = tempTotalPesanan;
            totalTransaksi = tempTotalHarga;
            isLoading = false;
          });
        }
      } else {
        throw Exception("Gagal mengambil data");
      }
    } catch (e) {
      debugPrint("Error riwayat pesanan: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<dynamic> get filteredPesanan {
    return listPesanan.where((p) {
      String layanan = (p['layanan'] ?? '').toLowerCase();
      String idOrder = p['id'].toString();
      String status = (p['status'] ?? '').toLowerCase();

      bool matchSearch =
          layanan.contains(searchQuery.toLowerCase()) ||
          idOrder.contains(searchQuery);

      bool matchTab = true;
      if (activeTab == 'Aktif') {
        matchTab = !status.contains('selesai') && !status.contains('batal');
      } else if (activeTab == 'Selesai') {
        matchTab = status.contains('selesai');
      }

      return matchSearch && matchTab;
    }).toList();
  }

  Color _getStatusColor(String status) {
    String s = status.toLowerCase();
    if (s.contains('menunggu konfirmasi')) return Colors.orange;
    if (s.contains('menunggu pembayaran')) return Colors.redAccent;
    if (s.contains('batal') || s.contains('dibatalkan')) return Colors.red;
    if (s.contains('lunas') || s.contains('diproses') || s.contains('dicuci')) {
      return Colors.orange.shade700;
    }
    if (s.contains('dijemput') || s.contains('diantar')) return Colors.blue;
    if (s.contains('selesai')) return Colors.green;
    return Colors.grey;
  }

  IconData _getServiceIcon(String layanan) {
    String l = layanan.toLowerCase();
    if (l.contains('kering')) return Icons.air;
    if (l.contains('setrika')) return Icons.iron_outlined;
    if (l.contains('kilat')) return Icons.bolt;
    if (l.contains('sepatu')) return Icons.pets;
    return Icons.checkroom_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Pesanan Saya',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: isLoading || !isLocaleReady
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                _buildHeaderBar(),
                Expanded(
                  child: filteredPesanan.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _fetchRiwayatPesanan,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: 20,
                            ),
                            itemCount: filteredPesanan.length,
                            itemBuilder: (context, index) {
                              var pesanan = filteredPesanan[index];
                              return _buildOrderCard(pesanan);
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
              hintText: 'Cari pesanan...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF4F6F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                    horizontal: 18,
                    vertical: 8,
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
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xFF00A2E9), Color(0xFF5B61F4)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Transaksi Sukses',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Rp ${NumberFormat('#,###', 'id_ID').format(totalTransaksi)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Pesanan Berhasil',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      totalPesanan.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> pesanan) {
    String status = pesanan['status'] ?? 'Proses';
    double berat = double.tryParse(pesanan['berat']?.toString() ?? '0') ?? 0.0;
    int totalHarga =
        (double.tryParse(pesanan['total_harga']?.toString() ?? '0') ?? 0)
            .toInt();
    String dateStr = pesanan['created_at'] != null
        ? DateFormat(
            'dd MMM yyyy',
            'id_ID',
          ).format(DateTime.parse(pesanan['created_at']))
        : '-';

    // Format ID Order: PP-YYYYMMDD-XXX
    DateTime date = DateTime.parse(pesanan['created_at'] ?? DateTime.now().toString());
    String formattedDate = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    String idOrder =
        'PP-$formattedDate-${pesanan['id'].toString().padLeft(3, '0')}';

    bool butuhPembayaran = status.toLowerCase().contains('menunggu pembayaran');
    bool pesananSelesai = status.toLowerCase() == 'selesai';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1FAFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getServiceIcon(pesanan['layanan']),
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
                            pesanan['layanan'] ?? 'Layanan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
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
                      '$idOrder • ${berat > 0 ? (berat % 1 == 0 ? berat.toInt() : berat) : '?'} kg',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(totalHarga)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        butuhPembayaran
                            ? 'Pembayaran tertunda'
                            : pesananSelesai
                            ? 'Pesanan Selesai'
                            : 'Sedang diproses',
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // --- LOGIKA TOMBOL AKSI BERDASARKAN STATUS ---
              if (butuhPembayaran)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CustomerPaymentScreen(dataPesanan: pesanan),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Bayar Sekarang',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else if (pesananSelesai)
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerHomeScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, size: 14, color: Color(0xFF00A2E9)),
                      SizedBox(width: 4),
                      Text(
                        'Pesan Lagi',
                        style: TextStyle(
                          color: Color(0xFF00A2E9),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CustomerTrackingScreen(
                          orderId: idOrder,
                          status: status,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Lacak',
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
            'Pesanan tidak ditemukan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Coba ubah filter tab atau kata kunci pencarian Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, a1, a2) => const CustomerHomeScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, a1, a2) => const CustomerProfileScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Pesanan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
  void _showRatingDialog(BuildContext context, String orderId) {
    int _rating = 5;
    TextEditingController _ulasanController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Beri Ulasan Layanan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Bagaimana kualitas cucian dan performa kurir kami?'),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ulasanController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Tulis ulasan Anda (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    _submitRating(orderId, _rating, _ulasanController.text);
                  },
                  child: const Text('Kirim'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating(String orderId, int rating, String ulasan) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('auth_token') ?? '';

      var response = await http.post(
        Uri.parse("$apiUrl/pesanan/$orderId/rating"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'rating': rating,
          'ulasan': ulasan,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terima kasih! Ulasan berhasil dikirim.')),
        );
        _fetchOrders(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim ulasan')),
        );
      }
    } catch (e) {
      print('Error submit rating: $e');
    }
  }

}
