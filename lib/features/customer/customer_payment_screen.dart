import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/services/api_config.dart';
import '../../../core/services/auth_http.dart' as http;
import '../../../core/services/midtrans_service.dart';
import '../../../core/theme/app_colors.dart';

class CustomerPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> dataPesanan;

  const CustomerPaymentScreen({super.key, required this.dataPesanan});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  bool isLoading = false;
  String selectedPayment = 'cod'; // Pilihan: 'cod', 'qris', 'bank_transfer', 'credit_card'

  @override
  void initState() {
    super.initState();
  }

  // =========================================================
  // 1. PROSES PEMBAYARAN COD (BAYAR KE KURIR)
  // Mengirim request ke Backend agar status berpindah ke 'Sedang Dicuci'
  // =========================================================
  Future<void> _konfirmasiPesananCOD() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final orderId = widget.dataPesanan['id'];
    int totalHarga = (double.tryParse(widget.dataPesanan['total_harga']?.toString() ?? '0') ?? 0).toInt();

    try {
      final url = Uri.parse('$apiBaseUrl/pesanan/$orderId/pilih-metode-pembayaran');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'payment_method': 'cod'}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Tampilkan dialog sukses COD
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 44),
                  ),
                  const SizedBox(height: 16),
                  const Text('Metode COD Terkonfirmasi!',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'No. Pesanan: #${widget.dataPesanan['id']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB74D)),
                    ),
                    child: Column(
                      children: [
                        const Row(children: [
                          Icon(Icons.payments_outlined,
                              color: Color(0xFFE65100), size: 18),
                          SizedBox(width: 8),
                          Text('Siapkan Uang Tunai:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100))),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(totalHarga)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pakaian Anda sekarang sedang dicuci. Pembayaran tunai diserahkan ke kurir saat cucian diantarkan.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, true); // Kirim true agar layar Pesanan Saya otomatis refresh
                      },
                      child: const Text('Lihat Status Pesanan',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal konfirmasi COD (${response.statusCode}): ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi gagal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // 2. PROSES PEMBAYARAN MIDTRANS (QRIS / VA / KARTU KREDIT)
  // Menghubungi Midtrans Snap -> Buka WebView -> Update Status
  // =========================================================
  Future<void> _prosesPembayaranMidtrans() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    int totalHarga = (double.tryParse(widget.dataPesanan['total_harga']?.toString() ?? '0') ?? 0).toInt();
    final orderNum = widget.dataPesanan['id'].toString();
    final midtransOrderId = 'PINT-$orderNum-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('name') ?? 'Pelanggan Pint Point';
      final userEmail = prefs.getString('email') ?? 'pelanggan@pintpoint.com';
      final userPhone = prefs.getString('no_hp') ?? '081234567890';

      final redirectUrl = await MidtransService().getTransactionToken(
        orderId: midtransOrderId,
        grossAmount: totalHarga,
        customerName: userName,
        customerEmail: userEmail,
        customerPhone: userPhone,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (redirectUrl == null || redirectUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan halaman pembayaran dari Midtrans.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Buka WebView Snap Midtrans
      final paymentSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (ctx) => PaymentWebViewScreen(
            paymentUrl: redirectUrl,
            orderId: midtransOrderId,
            onPaymentComplete: (bool success) {
              // Callback status WebView
            },
          ),
        ),
      );

      if (!mounted) return;

      if (paymentSuccess == true) {
        // Tampilkan dialog pembayaran sukses
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 44),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pembayaran Berhasil!',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'No. Pesanan: #${widget.dataPesanan['id']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Column(
                      children: [
                        const Row(children: [
                          Icon(Icons.verified_rounded,
                              color: Color(0xFF1976D2), size: 18),
                          SizedBox(width: 8),
                          Text('Lunas via Midtrans:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2))),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(totalHarga)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pembayaran Anda telah diverifikasi otomatis. Pakaian Anda sekarang sedang dicuci.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, true); // Refresh daftar pesanan
                      },
                      child: const Text('Lihat Status Pesanan',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran belum diselesaikan atau dibatalkan.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulai transaksi Midtrans: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalHargaAsli =
        (double.tryParse(widget.dataPesanan['total_harga']?.toString() ?? '0') ?? 0)
            .toInt();
    String layananName = widget.dataPesanan['layanan'] ?? 'Layanan';
    String beratPesanan = widget.dataPesanan['berat'] != null
        ? '${widget.dataPesanan['berat']} kg'
        : 'Menunggu timbang';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout Pembayaran',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rincian Pesanan Card
              const Text(
                "Rincian Pesanan",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("ID Pesanan",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          "#${widget.dataPesanan['id']}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Layanan",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Flexible(
                          child: Text(
                            layananName,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Berat Aktual",
                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(
                          beratPesanan,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Tagihan",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(totalHargaAsli)}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ============================================
              // PILIH METODE PEMBAYARAN
              // ============================================
              const Text(
                "Pilih Metode Pembayaran",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // --- 1. OPSI: BAYAR TUNAI (COD) ---
              _buildPaymentOption(
                keyId: 'cod',
                title: 'Bayar Tunai (COD)',
                subtitle: 'Bayar ke kurir saat laundry bersih diantarkan ke rumah Anda',
                icon: Icons.payments_outlined,
                activeColor: Colors.green,
                tag: 'Tunai',
              ),
              const SizedBox(height: 10),

              // --- 2. OPSI: QRIS (MIDTRANS) ---
              _buildPaymentOption(
                keyId: 'qris',
                title: 'QRIS / Scan QR (Instant)',
                subtitle: 'GoPay, ShopeePay, OVO, Dana, LinkAja, BCA QRIS',
                icon: Icons.qr_code_scanner_rounded,
                activeColor: AppColors.primary,
                tag: 'Midtrans Snap',
              ),
              const SizedBox(height: 10),

              // --- 3. OPSI: TRANSFER BANK (MIDTRANS) ---
              _buildPaymentOption(
                keyId: 'bank_transfer',
                title: 'Transfer Bank (Virtual Account)',
                subtitle: 'BCA, Mandiri, BRI, BNI, Permata, dll',
                icon: Icons.account_balance_rounded,
                activeColor: AppColors.primary,
                tag: 'Midtrans Snap',
              ),
              const SizedBox(height: 10),

              // --- 4. OPSI: KARTU KREDIT (MIDTRANS) ---
              _buildPaymentOption(
                keyId: 'credit_card',
                title: 'Kartu Kredit / Debit Online',
                subtitle: 'Visa, Mastercard, JCB (3D Secure)',
                icon: Icons.credit_card_rounded,
                activeColor: AppColors.primary,
                tag: 'Midtrans Snap',
              ),
              const SizedBox(height: 20),

              // --- BANNER INFO DINAMIS ---
              if (selectedPayment == 'cod')
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Color(0xFFF57F17)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Siapkan uang tunai sejumlah Rp ${NumberFormat('#,###', 'id_ID').format(totalHargaAsli)} saat kurir mengantarkan laundry Anda.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20, color: Color(0xFF1976D2)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pembayaran aman & terverifikasi otomatis via gerbang resmi Midtrans. Cucian langsung diproses begitu lunas.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1)),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // --- TOMBOL AKSI UTAMA ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPayment == 'cod'
                        ? const Color(0xFF2E7D32)
                        : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          if (selectedPayment == 'cod') {
                            _konfirmasiPesananCOD();
                          } else {
                            _prosesPembayaranMidtrans();
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedPayment == 'cod'
                                  ? Icons.check_circle_outline
                                  : Icons.lock_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedPayment == 'cod'
                                  ? 'Konfirmasi Pesanan (COD)'
                                  : 'Bayar Sekarang (Midtrans)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Opsi Metode Pembayaran Interaktif
  Widget _buildPaymentOption({
    required String keyId,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required String tag,
  }) {
    final bool isSelected = selectedPayment == keyId;

    return GestureDetector(
      onTap: () => setState(() => selectedPayment = keyId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: activeColor.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.15) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isSelected ? Colors.black87 : Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeColor.withOpacity(0.15)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeColor : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? activeColor : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// PaymentWebViewScreen - Handle payment di WebView Midtrans
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final Function(bool) onPaymentComplete;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late WebViewController _webViewController;
  bool isLoading = true;
  Timer? _statusTimer;
  final int _pollIntervalSeconds = 3;
  int _elapsedSeconds = 0;
  final int _maxTimeoutSeconds = 60 * 5; // 5 menit

  @override
  void initState() {
    super.initState();
    _initWebView();
    // Polling status pembayaran di server
    _statusTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      _elapsedSeconds += _pollIntervalSeconds;
      _pollPaymentStatus();
      if (_elapsedSeconds >= _maxTimeoutSeconds) {
        _statusTimer?.cancel();
        if (mounted) {
          widget.onPaymentComplete(false);
          Navigator.pop(context, false);
        }
      }
    });
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => isLoading = true);
            debugPrint("Payment URL started: $url");
          },
          onPageFinished: (String url) {
            setState(() => isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");
          },
          onUrlChange: (UrlChange change) {
            debugPrint("URL Changed: ${change.url}");
            _checkPaymentStatus(change.url ?? '');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    if (url.contains('finish') ||
        url.contains('success') ||
        url.contains('status=settlement') ||
        url.contains('status=capture')) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _statusTimer?.cancel();
          widget.onPaymentComplete(true);
          Navigator.pop(context, true);
        }
      });
    } else if (url.contains('error') ||
        url.contains('cancel') ||
        url.contains('status=deny')) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _statusTimer?.cancel();
          widget.onPaymentComplete(false);
          Navigator.pop(context, false);
        }
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollPaymentStatus() async {
    try {
      final res = await midtransService.getPaymentStatus(
        orderId: widget.orderId,
      );
      if (res['success'] == true) {
        final status = (res['status'] ?? '').toString().toLowerCase();
        if (status.contains('settlement') ||
            status.contains('capture') ||
            status.contains('success') ||
            status.contains('paid')) {
          _statusTimer?.cancel();
          if (mounted) {
            widget.onPaymentComplete(true);
            Navigator.pop(context, true);
          }
        } else if (status.contains('deny') ||
            status.contains('cancel') ||
            status.contains('expire') ||
            status.contains('failure')) {
          _statusTimer?.cancel();
          if (mounted) {
            widget.onPaymentComplete(false);
            Navigator.pop(context, false);
          }
        }
      }
    } catch (e) {
      debugPrint('[PaymentWebView] poll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Pembayaran Midtrans',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}