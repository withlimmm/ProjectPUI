import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';

// --- IMPORT PAKET PETA GRATIS & LOKASI ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';

// Import halaman lain
import 'customer_home.dart';
import 'customer_order_screen.dart';
import '../auth/auth_screen.dart';
import 'customer_edit_profile_screen.dart';
import '../../../core/services/api_config.dart';
import 'customer_settings_pages.dart';
import '../notification/notification_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../../core/services/badge_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  String userId = "";
  String userName = "Pengguna";
  String userEmail = "-";
  String userPhone = "-";
  String? fotoProfilUrl;

  bool isLoading = true;
  List<dynamic> addressList = [];

  String get apiUrl => apiBaseUrl;
  String get storageUrl => storageBaseUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // --- FUNGSI MENGAMBIL DATA PROFIL ---
  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? savedId = prefs.getString('user_id');
    userId = savedId ?? "";

    debugPrint("DEBUG: Memuat profil untuk userId: $userId");

    setState(() {
      userName = prefs.getString('user_name') ?? "Pengguna";
    });

    if (userId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl/profil/$userId'),
          headers: {'Accept': 'application/json'},
        );

        debugPrint("DEBUG: Response profil status: ${response.statusCode}");
        debugPrint("DEBUG: Response body: ${response.body}");

        if (response.statusCode == 200) {
          var data = json.decode(response.body);

          setState(() {
            userName = data['name'] ?? userName;
            userEmail = data['email']?.toString() ?? '-';
            userPhone = data['no_hp']?.toString() ?? '-';
            fotoProfilUrl = data['foto_profil'];
            isLoading = false;
          });

          await prefs.setString('user_name', userName);
        } else {
          setState(() => isLoading = false);
          _showPesan("Gagal memuat profil (Status: ${response.statusCode})");
        }

        await _fetchAddresses();
      } catch (e) {
        setState(() => isLoading = false);
        debugPrint("Gagal koneksi ke server profil: $e");
        _showPesan("Gagal terhubung ke server. Periksa koneksi IP $apiUrl");
      }
    } else {
      setState(() => isLoading = false);
      debugPrint("DEBUG: userId kosong, tidak memanggil API");
    }
  }

  // --- FUNGSI TARIK DATA ALAMAT ---
  Future<void> _fetchAddresses() async {
    if (userId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/alamat/$userId'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          addressList = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Gagal tarik alamat: $e");
    }
  }

  // --- NAVIGASI KE HALAMAN TAMBAH ALAMAT BARU ---
  void _navigateToAddAddress() async {
    // Menunggu hasil dari halaman Tambah Alamat
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerAddAddressScreen(userId: userId),
      ),
    );

    // Jika kembaliannya true (berhasil simpan), refresh daftar alamat
    if (result == true) {
      _showPesan("Alamat berhasil ditambahkan!", isSukses: true);
      _fetchAddresses();
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  // --- FUNGSI NONAKTIFKAN AKUN ---
  Future<void> _deactivateAccount() async {
    if (userId.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/profil/deactivate/$userId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        _showPesan("Akun Anda telah dinonaktifkan.", isSukses: true);
        _logout(); // Langsung keluar setelah dinonaktifkan
      } else {
        setState(() => isLoading = false);
        _showPesan("Gagal menonaktifkan akun (Status: ${response.statusCode})");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showPesan("Gagal terhubung ke server saat menonaktifkan akun.");
      debugPrint("Error deactivate: $e");
    }
  }

  void _showDeactivateConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Nonaktifkan Akun',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menonaktifkan akun? Anda tidak akan bisa masuk kembali kecuali akun diaktifkan kembali oleh admin.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivateAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ya, Nonaktifkan',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    if (names.isEmpty || names[0].isEmpty) return "U";
    if (names.length == 1) return names[0][0].toUpperCase();
    return "${names[0][0]}${names[names.length - 1][0]}".toUpperCase();
  }

  void _showPesan(String pesan, {bool isSukses = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isSukses ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNavigationBar: _buildBottomNav(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: 60,
                        bottom: 40,
                        left: 20,
                        right: 20,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Profil Saya',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  final reloadNeeded = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CustomerEditProfileScreen(
                                            currentName: userName,
                                            currentPhone: userPhone,
                                            currentPhotoUrl: fotoProfilUrl,
                                          ),
                                    ),
                                  );
                                  // ✅ BARU: Jika foto diupdate, reload data & clear cache
                                  if (reloadNeeded == true) {
                                    if (mounted) {
                                      setState(() => isLoading = true);
                                    }
                                    // Clear image cache
                                    imageCache.clearLiveImages();
                                    imageCache.clear();
                                    imageCache.clearLiveImages();

                                    await _loadProfileData();
                                    if (mounted) {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade300,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  image:
                                      (fotoProfilUrl != null &&
                                          fotoProfilUrl!.isNotEmpty)
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            '$storageUrl/$fotoProfilUrl?t=${DateTime.now().millisecondsSinceEpoch}',
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    (fotoProfilUrl == null ||
                                        fotoProfilUrl!.isEmpty)
                                    ? Center(
                                        child: Text(
                                          _getInitials(userName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),

                          const SizedBox(height: 15),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            userEmail,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _buildInfoCard(
                              title: 'Informasi Kontak',
                              children: [
                                _buildInfoRow('Email', userEmail),
                                const Divider(
                                  height: 20,
                                  color: Color(0xFFF1F5F9),
                                ),
                                _buildInfoRow('No. WhatsApp', userPhone),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // KARTU ALAMAT DINAMIS DENGAN TOMBOL BARU
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Alamat Tersimpan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap:
                                            _navigateToAddAddress, // Panggil Halaman Peta
                                        child: const Text(
                                          '+ Tambah',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  if (addressList.isEmpty)
                                    const Text(
                                      'Belum ada alamat. Silakan tambah alamat Anda.',
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: addressList.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(
                                            height: 20,
                                            color: Color(0xFFF1F5F9),
                                          ),
                                      itemBuilder: (context, index) {
                                        var alamat = addressList[index];
                                        return _buildAddressItem(
                                          alamat['label'] ?? 'Alamat',
                                          (alamat['is_utama'] == 1 ||
                                                  alamat['is_utama'] == true)
                                              ? 'Utama'
                                              : '',
                                          alamat['alamat_lengkap'] ?? '-',
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Column(
                                children: [
                                  _buildMenuItem(
                                    Icons.account_balance_wallet_outlined,
                                    'Metode Pembayaran',
                                    Colors.green,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CustomerPaymentMethodScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.notifications_none,
                                    'Notifikasi',
                                    Colors.orange,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NotificationScreen(),
                                      ),
                                    ),
                                    trailing: ValueListenableBuilder<BadgeCounts>(
                                      valueListenable: BadgeService.counts,
                                      builder: (context, counts, child) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (counts.notif > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${counts.notif}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.chat_bubble_outline,
                                    'Chat',
                                    AppColors.primary,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ChatListScreen(),
                                      ),
                                    ),
                                    trailing: ValueListenableBuilder<BadgeCounts>(
                                      valueListenable: BadgeService.counts,
                                      builder: (context, counts, child) {
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (counts.chat > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${counts.chat}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.security_outlined,
                                    'Keamanan Akun',
                                    Colors.blue,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CustomerSecurityScreen(
                                              userId: userId,
                                            ),
                                      ),
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.star_border_outlined,
                                    'Beri Rating',
                                    Colors.purple,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CustomerRatingScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.help_outline,
                                    'Bantuan & FAQ',
                                    Colors.grey.shade700,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CustomerFAQScreen(),
                                      ),
                                    ),
                                  ),
                                  _buildMenuDivider(),
                                  _buildMenuItem(
                                    Icons.person_off_outlined,
                                    'Nonaktifkan Akun',
                                    Colors.redAccent,
                                    onTap: () => _showDeactivateConfirm(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: OutlinedButton.icon(
                                onPressed: () => _showLogoutConfirm(),
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Keluar',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.red.shade100,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  backgroundColor: Colors.red.shade50,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            Text(
                              'Pint Point Laundry v1.0.0',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAddressItem(String title, String badge, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                address,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    Color iconColor, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: AppColors.textDark,
        ),
      ),
      trailing: trailing ?? const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: AppColors.textLight,
      ),
      onTap: onTap,
    );
  }

  Widget _buildMenuDivider() {
    return const Divider(
      height: 1,
      color: Color(0xFFF1F5F9),
      indent: 60,
      endIndent: 20,
    );
  }

  void _showLogoutConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Keluar Aplikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Pint Point?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 2,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerHomeScreen()),
          );
        } else if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const CustomerOrderScreen(),
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

// ============================================================================
// HALAMAN BARU: TAMBAH ALAMAT DENGAN PETA GRATIS (FLUTTER MAP)
// ============================================================================
class CustomerAddAddressScreen extends StatefulWidget {
  final String userId;
  const CustomerAddAddressScreen({super.key, required this.userId});

  @override
  State<CustomerAddAddressScreen> createState() =>
      _CustomerAddAddressScreenState();
}

class _CustomerAddAddressScreenState extends State<CustomerAddAddressScreen> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _mapAddressController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  bool isUtama = false;
  bool isDetectingLocation = false;

  // Kontrol Peta Flutter Map
  late final MapController _mapController;
  LatLng _currentPosition = const LatLng(
    -7.3274,
    108.2207,
  ); // Titik Awal: Tasikmalaya

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _detectCurrentLocation(); // Otomatis cari lokasi saat dibuka
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // --- FUNGSI MENDAPATKAN LOKASI TERKINI (GPS) ---
  Future<void> _detectCurrentLocation() async {
    setState(() => isDetectingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS mati. Silakan nyalakan GPS Anda.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Izin lokasi ditolak.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Izin lokasi diblokir permanen.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      // Pindahkan kamera Peta ke lokasi terkini
      _mapController.move(currentLatLng, 17.0);

      setState(() {
        _currentPosition = currentLatLng;
      });

      // Terjemahkan koordinat
      await _getAddressFromLatLng(
        currentLatLng.latitude,
        currentLatLng.longitude,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isDetectingLocation = false);
    }
  }

  // --- FUNGSI MENERJEMAHKAN TITIK PETA MENJADI TEKS ALAMAT (GRATIS NOMINATIM API) ---
  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    setState(() => isDetectingLocation = true);
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'PintPointLaundryApp/1.0',
        }, // Wajib ada untuk OSM
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _mapAddressController.text =
                data['display_name'] ?? "Alamat tidak ditemukan";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _mapAddressController.text = "Gagal memuat alamat. Cek koneksi.",
        );
      }
    } finally {
      if (mounted) setState(() => isDetectingLocation = false);
    }
  }

  // --- FUNGSI SIMPAN KE DATABASE LARAVEL ---
  Future<void> _saveAddress() async {
    if (_labelController.text.isEmpty || _mapAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Label dan Lokasi Peta wajib diisi!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    String alamatFinal = _mapAddressController.text;
    if (_detailController.text.isNotEmpty) {
      alamatFinal += " (Patokan: ${_detailController.text})";
    }

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/alamat/tambah'),
        headers: {'Accept': 'application/json'},
        body: {
          'user_id': widget.userId,
          'label': _labelController.text,
          'alamat_lengkap': alamatFinal,
          'is_utama': isUtama.toString(),
        },
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception("Gagal menyimpan");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan jaringan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pilih Titik Lokasi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: Column(
        children: [
          // 1. AREA PETA GRATIS (FLUTTER MAP)
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 15.0,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() => _currentPosition = position.center);
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _getAddressFromLatLng(
                          _currentPosition.latitude,
                          _currentPosition.longitude,
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pintpoint.app',
                    ),
                  ],
                ),

                // Pin Statis di Tengah Layar (Gaya Gojek/Grab)
                const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 50, color: Colors.red),
                    SizedBox(
                      height: 50,
                    ), // Spasi agar ujung bawah pin pas di tengah titik
                  ],
                ),

                // Tombol Deteksi Lokasi Otomatis
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    onPressed: _detectCurrentLocation,
                    child: isDetectingLocation
                        ? const CircularProgressIndicator()
                        : const Icon(
                            Icons.my_location,
                            color: AppColors.primary,
                          ),
                  ),
                ),
              ],
            ),
          ),

          // 2. AREA FORM INPUT DETAIL
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi dari Peta',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _mapAddressController,
                      maxLines: 2, // Agar alamat panjang tidak terpotong
                      decoration: InputDecoration(
                        hintText: 'Geser peta untuk mendeteksi alamat...',
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(
                          Icons.map,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    const Text(
                      'Detail Patokan (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _detailController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Rumah cat biru, sebelah warung',
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    const Text(
                      'Simpan Sebagai',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Rumah, Kosan, Kantor',
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SwitchListTile(
                      title: const Text(
                        'Jadikan Alamat Utama',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: isUtama,
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => isUtama = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: _saveAddress,
                        child: const Text(
                          'Simpan Alamat',
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
          ),
        ],
      ),
    );
  }
}
