import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';

// --- IMPORT HALAMAN LAIN UNTUK NAVIGASI BAWAH & PESANAN ---
import 'customer_order_screen.dart';
import 'customer_profile_screen.dart';
import 'customer_create_order_screen.dart'; // Import halaman buat pesanan baru
import '../../../core/services/fcm_service.dart';
import '../../../core/widgets/badge_icon.dart';
import '../notification/notification_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../../core/services/badge_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String userName = "Pelanggan";
  String userId = "";

  bool isLoading = true;
  List<dynamic> layananList = [];
  List<dynamic> promoList = [];
  Map<String, dynamic>? pesananAktif;

  // ✅ BARU: Tambah variable untuk alamat
  String selectedAddressName = "";
  String selectedAddressDetail = "";
  int? selectedAddressId;
  List<dynamic> addressList = [];

  // ✅ BARU: Tambah variable untuk jam operasional
  bool isShopOpen = true;
  String jamBuka = "08:00";
  String jamTutup = "17:00";

  // --- LOGIKA PINTAR ALAMAT API ---
  String get apiUrl => apiBaseUrl;

  // ✅ BARU: Fungsi load alamat default dari profil
  Future<void> _loadDefaultAddress() async {
    if (userId.isEmpty) return;

    try {
      // Mengambil dari profil karena alamat utama sekarang disinkronkan ke tabel users
      final response = await http.get(Uri.parse('$apiUrl/profil/$userId'));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (mounted) {
          setState(() {
            if (data['alamat'] != null &&
                data['alamat'].toString().isNotEmpty) {
              selectedAddressName = 'Alamat Utama';
              selectedAddressDetail = data['alamat'];
            } else {
              selectedAddressName = 'Belum ada alamat';
              selectedAddressDetail = 'Tambahkan alamat di profil';
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error load alamat dari profil: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // ✅ BARU: Reload alamat setiap kali screen ditampilkan ulang
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDefaultAddress();
      }
    });
  }

  Future<void> _loadInitialData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Tampilkan data lokal seketika (Optimistic Loading)
    if (mounted) {
      setState(() {
        String fullName = prefs.getString('user_name') ?? 'Pelanggan';
        userName = fullName.split(' ')[0];

        var savedId = prefs.get('user_id');
        userId = savedId != null ? savedId.toString() : "";

        // KUNCI KECEPATAN: Matikan loading seketika!
        isLoading = false;
      });
    }

    // ✅ BARU: Load alamat default setelah userId ready
    await _loadDefaultAddress();

    // ✅ BARU: Inisialisasi Firebase Cloud Messaging
    if (userId.isNotEmpty) {
      FcmService().initPushNotification();
    }

    // Ambil data terbaru dari Laravel di latar belakang
    _fetchDashboardData();
  }

  // --- FUNGSI MENGAMBIL DATA DARI LARAVEL ---
  Future<void> _fetchDashboardData() async {
    try {
      // 1. Ambil Data Layanan
      final responseLayanan = await http.get(Uri.parse('$apiUrl/layanan'));
      if (responseLayanan.statusCode == 200) {
        if (mounted) {
          setState(() {
            layananList = json.decode(responseLayanan.body);
          });
        }
      }

      // 2. Ambil Data Promo
      final responsePromo = await http.get(Uri.parse('$apiUrl/promo'));
      if (responsePromo.statusCode == 200) {
        if (mounted) {
          setState(() {
            promoList = json.decode(responsePromo.body);
          });
        }
      }

      // 3. Ambil Pesanan Aktif
      if (userId.isNotEmpty) {
        final responsePesanan = await http.get(
          Uri.parse('$apiUrl/pesanan-aktif/$userId'),
        );
        if (responsePesanan.statusCode == 200) {
          var dataPesanan = json.decode(responsePesanan.body);
          // Pastikan data yang dikembalikan bukan kosong
          if (dataPesanan != null &&
              dataPesanan.toString() != "[]" &&
              dataPesanan.toString() != "{}") {
            if (mounted) {
              setState(() {
                pesananAktif = dataPesanan;
              });
            }
          }
        }
      }
      
      // 4. Ambil Jam Operasional
      final responseDelivery = await http.get(Uri.parse('$apiUrl/settings/delivery'));
      if (responseDelivery.statusCode == 200) {
        final data = json.decode(responseDelivery.body);
        if (mounted) {
          setState(() {
            jamBuka = data['jam_buka'];
            jamTutup = data['jam_tutup'];
            final String currentTime = DateFormat('HH:mm').format(DateTime.now());
            if (currentTime.compareTo(jamBuka) < 0 || currentTime.compareTo(jamTutup) > 0) {
              isShopOpen = false;
            } else {
              isShopOpen = true;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error mengambil data dashboard: $e");
    }
  }

  // Fungsi untuk mengubah teks ikon dari Laravel menjadi Ikon Flutter
  IconData _getIconData(String iconString) {
    switch (iconString) {
      case 'fas fa-wind':
        return Icons.air;
      case 'fas fa-star':
        return Icons.iron_outlined;
      case 'fas fa-bolt':
        return Icons.bolt;
      case 'fas fa-shoe-prints':
        return Icons.pets;
      default:
        return Icons.checkroom_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _buildChatFAB(),
      bottomNavigationBar: _buildBottomNav(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // ✅ BARU: Refresh alamat + data dashboard saat swipe down
                await _loadDefaultAddress();
                await _fetchDashboardData();
              },
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    // Latar Belakang Biru
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                    ),

                    SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),

                          // SELALU TAMPILKAN KARTU INI
                          _buildPesananAktifCard(),

                          const SizedBox(height: 25),

                          // --- LAYANAN KAMI ---
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Layanan Kami',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          layananList.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: GridView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 15,
                                          mainAxisSpacing: 15,
                                          childAspectRatio: 0.85,
                                        ),
                                    itemCount: layananList.length,
                                    itemBuilder: (context, index) {
                                      var layanan = layananList[index];

                                      // --- PEMANGGILAN YANG SUDAH DIPERBARUI ---
                                      return _buildServiceCard(
                                        layanan, // Data spesifik
                                        layananList, // Semua data layanan
                                        layanan['nama_layanan'] ?? 'Layanan',
                                        layanan['deskripsi'] ?? '',
                                        'Rp ${NumberFormat('#,###', 'id_ID').format(layanan['harga'] ?? 0)}/kg',
                                        _getIconData(layanan['ikon'] ?? ''),
                                        AppColors.primary,
                                        const Color(0xFFE1F5FE),
                                      );
                                    },
                                  ),
                                ),

                          const SizedBox(height: 25),

                          // --- PROMO SPESIAL ---
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Promo Spesial',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          promoList.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: promoList.length,
                                  itemBuilder: (context, index) {
                                    var promo = promoList[index];
                                    return _buildPromoCard(
                                      promo['judul'] ?? 'Promo',
                                      promo['deskripsi'] ?? '',
                                      promo['kode_promo'],
                                    );
                                  },
                                ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // === WIDGET KOMPONEN ===

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selamat siang,',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        userName,
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
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                child: ValueListenableBuilder<BadgeCounts>(
                  valueListenable: BadgeService.counts,
                  builder: (context, counts, child) {
                    return BadgeIcon(
                      icon: Icons.notifications_none,
                      color: Colors.white,
                      count: counts.notif,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ BARU: Tampilkan nama alamat
                      Text(
                        selectedAddressName.isNotEmpty
                            ? selectedAddressName
                            : 'Belum ada alamat',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // ✅ BARU: Tampilkan detail alamat dengan truncate
                      Text(
                        selectedAddressDetail.isNotEmpty
                            ? selectedAddressDetail
                            : 'Tambahkan alamat di profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPesananAktifCard() {
    if (pesananAktif == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_laundry_service_outlined,
                  color: Colors.grey.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Belum ada pesanan aktif',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Yuk, percayakan cucian kotor Anda\nkepada Pint Point hari ini!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orange.shade700,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Pesanan Aktif',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pesananAktif!['status'] ?? 'Proses',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(builder: (context) {
                        DateTime date = DateTime.parse(pesananAktif!['created_at'] ?? DateTime.now().toString());
                        String formattedDate = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
                        String formattedId = 'PP-$formattedDate-${pesananAktif!['id'].toString().padLeft(3, '0')}';
                        return Text(
                          'Pesanan #$formattedId',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        );
                      }),
                      Text(
                        pesananAktif!['berat'] != null
                            ? '${pesananAktif!['berat']} kg'
                            : 'Menunggu timbang',
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pesananAktif!['layanan'] ?? 'Layanan',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Dipesan pada: ${pesananAktif!['created_at'] != null ? pesananAktif!['created_at'].toString().substring(0, 10) : '-'}',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) =>
                        const CustomerOrderScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lihat di Pesanan',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PARAMETER SUDAH DIPERBARUI ---
  Widget _buildServiceCard(
    dynamic layananData,
    List<dynamic> semuaLayanan,
    String title,
    String subtitle,
    String price,
    IconData icon,
    Color iconColor,
    Color bgColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),

          // --- FUNGSI ONTAP MENGARAH KE HALAMAN BUAT PESANAN ---
          onTap: () {
            if (!isShopOpen) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Toko Tutup"),
                  content: Text("Maaf, Pint Point beroperasi jam $jamBuka - $jamTutup WIB."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Mengerti"),
                    ),
                  ],
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerCreateOrderScreen(
                  selectedLayanan: layananData,
                  allLayanan: semuaLayanan,
                ),
              ),
            );
          },

          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard(String judul, String deskripsi, String? kodePromo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF42A5F5), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'PROMO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            judul,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            deskripsi,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (kodePromo != null && kodePromo.isNotEmpty) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'KODE: $kodePromo',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatFAB() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatListScreen(),
          ),
        );
      },
      backgroundColor: AppColors.primary,
      child: ValueListenableBuilder<BadgeCounts>(
        valueListenable: BadgeService.counts,
        builder: (context, counts, child) {
          return BadgeIcon(
            icon: Icons.chat_bubble_outline,
            color: Colors.white,
            count: counts.chat,
          );
        },
      ),
    );
  }

  // --- LOGIKA NAVIGASI MENU BAWAH ---
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 1) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) =>
                  const CustomerOrderScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 2) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) =>
                  const CustomerProfileScreen(),
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
}

