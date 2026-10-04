import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';

// --- IMPORT KE HALAMAN LANGKAH 2 (CHECKOUT) ---
import 'customer_checkout_screen.dart';

class CustomerCreateOrderScreen extends StatefulWidget {
  final Map<String, dynamic> selectedLayanan; // Layanan yang diklik di beranda
  final List<dynamic> allLayanan; // Semua daftar layanan untuk di-render ulang

  const CustomerCreateOrderScreen({
    super.key,
    required this.selectedLayanan,
    required this.allLayanan,
  });

  @override
  State<CustomerCreateOrderScreen> createState() =>
      _CustomerCreateOrderScreenState();
}

class _CustomerCreateOrderScreenState extends State<CustomerCreateOrderScreen> {
  late Map<String, dynamic> activeLayanan;
  Map<String, dynamic>? activePaket; // Paket durasi yang dipilih

  // --- BERAT DESIMAL ---
  double beratEstimasi = 3.0;

  TextEditingController catatanController = TextEditingController();

  // Ongkir diambil dari API (default Rp 10.000 flat)
  int ongkir = 10000;
  String jamBuka = '08:00';
  String jamTutup = '17:00';
  bool isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    activeLayanan = widget.selectedLayanan;
    // Auto-pilih paket pertama
    final pakets = List<Map<String, dynamic>>.from(
        widget.selectedLayanan['paket_durasi'] ?? []);
    if (pakets.isNotEmpty) activePaket = pakets.first;
    _fetchDeliveryConfig();
  }

  /// Ambil konfigurasi ongkir dari backend
  Future<void> _fetchDeliveryConfig() async {
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/settings/delivery'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            ongkir = (data['ongkir'] as num).toInt();
            jamBuka = data['jam_buka'] ?? '08:00';
            jamTutup = data['jam_tutup'] ?? '17:00';
            isLoadingConfig = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingConfig = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingConfig = false);
    }
  }

  // --- LOGIKA PERHITUNGAN YANG AKURAT ---
  int get subtotal {
    // Jika satuan per pcs/pasang → harga langsung × jumlah (berat dipakai sbg jumlah)
    final pakets = List<Map<String, dynamic>>.from(
        activeLayanan['paket_durasi'] ?? []);
    // Gunakan harga dari paket yang dipilih, fallback ke harga layanan
    int harga = 0;
    if (activePaket != null) {
      harga = int.tryParse(activePaket!['harga'].toString()) ?? 0;
    } else if (pakets.isNotEmpty) {
      harga = int.tryParse(pakets.first['harga'].toString()) ?? 0;
    } else {
      harga = int.tryParse(activeLayanan['harga']?.toString() ?? '0') ?? 0;
    }
    final satuan = activePaket?['satuan'] ?? 'kg';
    if (satuan == 'kg') {
      return (harga * beratEstimasi).round();
    } else {
      // pcs/pasang: berat dipakai sebagai jumlah item
      return (harga * beratEstimasi).round();
    }
  }

  int get totalAkhir {
    return subtotal + ongkir;
  }

  // --- FUNGSI BARU: PINDAH KE LANGKAH 2 ---
  void _lanjutKeLangkahDua() {
    final pakets = List<Map<String, dynamic>>.from(
        activeLayanan['paket_durasi'] ?? []);
    final selectedPaket = activePaket ?? (pakets.isNotEmpty ? pakets.first : null);

    // Nama layanan lengkap dengan paket
    String namaLengkap = activeLayanan['nama_layanan'] ?? '';
    if (selectedPaket != null &&
        selectedPaket['nama_paket'] != 'Reguler/Express') {
      namaLengkap +=
          ' (${selectedPaket['nama_paket']} ${selectedPaket['durasi_label']})';
    }

    // Validasi Jam Operasional
    final now = DateTime.now();
    final partsBuka = jamBuka.split(':');
    final partsTutup = jamTutup.split(':');
    if (partsBuka.length >= 2 && partsTutup.length >= 2) {
      final timeBuka = TimeOfDay(hour: int.tryParse(partsBuka[0]) ?? 8, minute: int.tryParse(partsBuka[1]) ?? 0);
      final timeTutup = TimeOfDay(hour: int.tryParse(partsTutup[0]) ?? 17, minute: int.tryParse(partsTutup[1]) ?? 0);
      
      final currentTime = now.hour * 60 + now.minute;
      final bukaTime = timeBuka.hour * 60 + timeBuka.minute;
      final tutupTime = timeTutup.hour * 60 + timeTutup.minute;

      if (currentTime < bukaTime || currentTime > tutupTime) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Toko Tutup'),
            content: Text('Maaf, jam operasional kami adalah $jamBuka - $jamTutup.\nSilakan pesan kembali pada jam buka.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return; // Hentikan proses
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCheckoutScreen(
          layanan: namaLengkap,
          berat: beratEstimasi,
          totalHarga: totalAkhir,
          catatan: catatanController.text,
          ongkir: ongkir,
          packageId: selectedPaket != null ? selectedPaket['id'].toString() : '',
        ),
      ),
    );
  }

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
      backgroundColor: Colors.white,
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
              'Buat Pesanan',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Langkah 1 dari 2',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimasi Total',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(totalAkhir)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              // Tambahan teks kecil agar pengguna tahu ada ongkir
              if (ongkir > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(Termasuk biaya jemput Rp ${NumberFormat('#,###', 'id_ID').format(ongkir)})',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  // --- PANGGIL FUNGSI NAVIGASI DI SINI ---
                  onPressed: _lanjutKeLangkahDua,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Selanjutnya',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Jenis Layanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 15),

            ...widget.allLayanan.map((layanan) {
              bool isSelected = activeLayanan['id'] == layanan['id'];
              final pakets = List<Map<String, dynamic>>.from(
                  layanan['paket_durasi'] ?? []);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        activeLayanan = layanan;
                        activePaket = pakets.isNotEmpty ? pakets.first : null;
                      });
                    },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF1FAFF) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconData(layanan['ikon'] ?? ''),
                          color: isSelected ? AppColors.primary : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              layanan['nama_layanan'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              layanan['deskripsi'] ?? '-',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Rp ${NumberFormat('#,###', 'id_ID').format(layanan['harga'])}/kg',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ), // Closes Container
              ), // Closes GestureDetector
            ], // Closes children of Column
          ); // Closes Column
        }).toList(),

            const SizedBox(height: 20),

            const Text(
              'Estimasi Berat (kg)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Tombol Minus (Turun 0.5 kg)
                      GestureDetector(
                        onTap: () {
                          if (beratEstimasi > 1.0) {
                            setState(() => beratEstimasi -= 0.5);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.remove,
                            color: beratEstimasi > 1.0
                                ? Colors.black
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                      // Angka Tengah
                      Column(
                        children: [
                          Text(
                            beratEstimasi % 1 == 0
                                ? beratEstimasi.toInt().toString()
                                : beratEstimasi.toString(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'kilogram',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      // Tombol Plus (Naik 0.5 kg)
                      GestureDetector(
                        onTap: () {
                          if (beratEstimasi < 20.0) {
                            setState(() => beratEstimasi += 0.5);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1FAFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimasi subtotal',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(subtotal)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Row(
              children: [
                Text(
                  'Catatan Khusus ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  '(opsional)',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Contoh: Jangan disetrika terlalu panas, pisahkan baju putih...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
