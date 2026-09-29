import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';

// ============================================================================
// 1. HALAMAN KEAMANAN AKUN (GANTI PASSWORD)
// ============================================================================
class CustomerSecurityScreen extends StatefulWidget {
  final String userId;
  const CustomerSecurityScreen({super.key, required this.userId});

  @override
  State<CustomerSecurityScreen> createState() => _CustomerSecurityScreenState();
}

class _CustomerSecurityScreenState extends State<CustomerSecurityScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool obscureOld = true;
  bool obscureNew = true;

  Future<void> _updatePassword() async {
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty) {
      _showPesan("Semua kolom wajib diisi!");
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showPesan("Konfirmasi kata sandi tidak cocok!");
      return;
    }

    if (_newPasswordController.text.length < 8) {
      _showPesan("Kata sandi baru minimal 8 karakter!");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/profil/ubah-password/${widget.userId}'),
        headers: {'Accept': 'application/json'},
        body: {
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showPesan("Kata sandi berhasil diperbarui!", isSukses: true);
        if (mounted) Navigator.pop(context);
      } else {
        _showPesan(data['message'] ?? "Gagal memperbarui kata sandi");
      }
    } catch (e) {
      _showPesan("Terjadi kesalahan koneksi.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showPesan(String pesan, {bool isSukses = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isSukses ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Keamanan Akun',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubah Kata Sandi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Gunakan kata sandi yang kuat dan unik untuk melindungi akun Anda.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 30),
            _buildPasswordField(
              label: 'Kata Sandi Lama',
              controller: _oldPasswordController,
              obscure: obscureOld,
              toggle: () => setState(() => obscureOld = !obscureOld),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              label: 'Kata Sandi Baru',
              controller: _newPasswordController,
              obscure: obscureNew,
              toggle: () => setState(() => obscureNew = !obscureNew),
            ),
            const SizedBox(height: 20),
            _buildPasswordField(
              label: 'Konfirmasi Kata Sandi Baru',
              controller: _confirmPasswordController,
              obscure: obscureNew,
              toggle: () => setState(() => obscureNew = !obscureNew),
            ),
            const SizedBox(height: 40),
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
                onPressed: isLoading ? null : _updatePassword,
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: 'Masukkan kata sandi',
            filled: true,
            fillColor: const Color(0xFFF4F6F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 2. HALAMAN METODE PEMBAYARAN
// ============================================================================
class CustomerPaymentMethodScreen extends StatelessWidget {
  const CustomerPaymentMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Metode Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pembayaran Instan (Midtrans)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 15),
          _buildPaymentItem(
            icon: Icons.account_balance_wallet,
            title: 'GoPay',
            subtitle: 'Otomatis terhubung saat checkout',
            color: Colors.blue,
          ),
          _buildPaymentItem(
            icon: Icons.account_balance,
            title: 'Bank Transfer (VA)',
            subtitle: 'BCA, Mandiri, BNI, BRI',
            color: Colors.orange,
          ),
          _buildPaymentItem(
            icon: Icons.qr_code_scanner,
            title: 'QRIS',
            subtitle: 'Scan QR menggunakan aplikasi apa saja',
            color: Colors.redAccent,
          ),
          const SizedBox(height: 30),
          const Text(
            'Pembayaran Manual',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 15),
          _buildPaymentItem(
            icon: Icons.money,
            title: 'Tunai (COD)',
            subtitle: 'Bayar saat kurir mengambil cucian',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. HALAMAN BANTUAN & FAQ
// ============================================================================
class CustomerFAQScreen extends StatelessWidget {
  const CustomerFAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Bantuan & FAQ',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          FAQItem(
            question: 'Berapa lama proses laundry?',
            answer:
                'Untuk layanan Reguler memakan waktu 2-3 hari. Untuk layanan Kilat memakan waktu 1 hari (24 jam), dan layanan Ekspres hanya 6-12 jam.',
          ),
          FAQItem(
            question: 'Apakah ada minimal berat cucian?',
            answer:
                'Ya, minimal berat cucian untuk layanan kiloan adalah 3 Kg. Jika kurang dari 3 Kg tetap akan dihitung 3 Kg.',
          ),
          FAQItem(
            question: 'Bagaimana jika ada pakaian yang rusak/hilang?',
            answer:
                'Pint Point Laundry memberikan garansi penggantian hingga 5x biaya laundry untuk pakaian yang terbukti rusak atau hilang saat dalam penanganan kami.',
          ),
          FAQItem(
            question: 'Apakah harga sudah termasuk ongkos kirim?',
            answer:
                'Ongkos kirim gratis untuk radius 3 KM dari outlet kami. Selebihnya akan dikenakan biaya flat Rp 5.000 - Rp 10.000.',
          ),
          FAQItem(
            question: 'Bagaimana cara melacak pesanan?',
            answer:
                'Anda bisa masuk ke menu "Pesanan" lalu klik tombol "Lacak" pada pesanan yang sedang aktif.',
          ),
        ],
      ),
    );
  }
}

class FAQItem extends StatefulWidget {
  final String question;
  final String answer;
  const FAQItem({super.key, required this.question, required this.answer});

  @override
  State<FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<FAQItem> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.question,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onTap: () => setState(() => isExpanded = !isExpanded),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
              child: Text(
                widget.answer,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. DIALOG RATING (BISA DIJADIKAN HALAMAN)
// ============================================================================
class CustomerRatingScreen extends StatefulWidget {
  const CustomerRatingScreen({super.key});

  @override
  State<CustomerRatingScreen> createState() => _CustomerRatingScreenState();
}

class _CustomerRatingScreenState extends State<CustomerRatingScreen> {
  int rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Beri Rating',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.star_rounded, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Bagaimana pengalaman Anda?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Rating Anda sangat berarti bagi kami untuk meningkatkan kualitas layanan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Tulis masukan Anda di sini...',
                filled: true,
                fillColor: const Color(0xFFF4F6F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
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
                onPressed: () {
                  if (rating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Silakan pilih rating terlebih dahulu!"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Terima kasih atas ulasan Anda!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Kirim Ulasan',
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
