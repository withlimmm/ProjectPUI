import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
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
  String selectedPayment = 'cod'; // Default: COD

  @override
  void initState() {
    super.initState();
  }

  // =========================================================
  // PROSES PEMBAYARAN COD
  // =========================================================
  Future<void> _konfirmasiPesananCOD() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    // Simulasi konfirmasi (tidak ada transaksi payment gateway)
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => isLoading = false);

    int totalHarga =
        (double.tryParse(widget.dataPesanan['total_harga'].toString()) ?? 0)
            .toInt();

    // Tampilkan dialog sukses
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
              const Text('Pesanan Berhasil Dibuat!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'No. Pesanan: #${widget.dataPesanan['id']}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13),
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
                      'Bayar langsung ke kurir saat laundry diantarkan',
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
                    Navigator.pop(context, {'success': true});
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
  }

  @override
  Widget build(BuildContext context) {
    int totalHargaAsli =
        (double.tryParse(widget.dataPesanan['total_harga'].toString()) ?? 0)
            .toInt();
    String layananName = widget.dataPesanan['layanan'] ?? 'Layanan';
    String beratPesanan = widget.dataPesanan['berat'] ?? 'Menunggu timbang';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Checkout Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail Pesanan Section
              const Text(
                "Rincian Pesanan",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    // ID Pesanan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "ID Pesanan",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          "#${widget.dataPesanan['id']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Layanan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Layanan",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          layananName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Berat
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Berat",
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          beratPesanan,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // Total Harga
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Harga",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rp ${NumberFormat('#,###', 'id_ID').format(totalHargaAsli)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ============================================
              // PILIH METODE PEMBAYARAN
              // ============================================
              const Text(
                "Pilih Metode Pembayaran",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // --- OPSI 1: COD (AKTIF) ---
              GestureDetector(
                onTap: () => setState(() => selectedPayment = 'cod'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedPayment == 'cod'
                        ? const Color(0xFFE8F5E9)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedPayment == 'cod'
                          ? Colors.green
                          : Colors.grey.shade200,
                      width: selectedPayment == 'cod' ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selectedPayment == 'cod'
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.payments_outlined,
                            color: selectedPayment == 'cod'
                                ? Colors.green.shade700
                                : Colors.grey,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bayar Tunai (COD)',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(
                              'Bayar ke kurir saat laundry diantarkan ke rumah Anda',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selectedPayment == 'cod'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selectedPayment == 'cod'
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // --- OPSI 2: QRIS (COMING SOON) ---
              _buildComingSoonMethod(
                icon: Icons.qr_code_scanner,
                label: 'QRIS / Scan QR',
                subtitle: 'GoPay, OVO, Dana, ShopeePay, dll',
              ),
              const SizedBox(height: 10),

              // --- OPSI 3: TRANSFER BANK (COMING SOON) ---
              _buildComingSoonMethod(
                icon: Icons.account_balance,
                label: 'Transfer Bank',
                subtitle: 'BCA, Mandiri, BRI, BNI, dll',
              ),
              const SizedBox(height: 10),

              // --- OPSI 4: KARTU KREDIT (COMING SOON) ---
              _buildComingSoonMethod(
                icon: Icons.credit_card,
                label: 'Kartu Kredit / Debit',
                subtitle: 'Visa, Mastercard, JCB',
              ),

              const SizedBox(height: 24),

              // --- INFO COD ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFFF57F17)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Siapkan uang tunai sejumlah Rp ${NumberFormat('#,###', 'id_ID').format(totalHargaAsli)} saat kurir mengantarkan laundry Anda.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5D4037)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- TOMBOL KONFIRMASI ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: isLoading ? null : _konfirmasiPesananCOD,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Konfirmasi Pesanan (COD)',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget untuk metode pembayaran yang belum tersedia
  Widget _buildComingSoonMethod({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey.shade400, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade500)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 11, color: Colors.grey),
              SizedBox(width: 3),
              Text('Segera Hadir',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ],
      ),
    );
  }
}

// PaymentWebViewScreen - Handle payment di WebView
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
  final int _maxTimeoutSeconds = 60 * 5; // 5 minutes

  @override
  void initState() {
    super.initState();
    _initWebView();
    // start polling payment status after WebView initialized
    _statusTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) {
      _elapsedSeconds += _pollIntervalSeconds;
      _pollPaymentStatus();
      if (_elapsedSeconds >= _maxTimeoutSeconds) {
        _statusTimer?.cancel();
        if (mounted) {
          widget.onPaymentComplete(false);
          Navigator.pop(context);
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
    // Check if URL contains finish/success indicator
    if (url.contains('finish') ||
        url.contains('success') ||
        url.contains('status=settlement') ||
        url.contains('status=capture')) {
      // Payment successful
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _statusTimer?.cancel();
          widget.onPaymentComplete(true);
          Navigator.pop(context);
        }
      });
    } else if (url.contains('error') ||
        url.contains('cancel') ||
        url.contains('status=pending') ||
        url.contains('status=deny')) {
      // Payment failed/cancelled
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _statusTimer?.cancel();
          widget.onPaymentComplete(false);
          Navigator.pop(context);
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
      // ignore: avoid_print
      print('[PaymentWebView] poll status for ${widget.orderId}: $res');
      if (res['success'] == true) {
        final status = (res['status'] ?? '').toString().toLowerCase();
        if (status.contains('settlement') ||
            status.contains('capture') ||
            status.contains('success')) {
          _statusTimer?.cancel();
          if (mounted) {
            widget.onPaymentComplete(true);
            Navigator.pop(context);
          }
        } else if (status.contains('deny') ||
            status.contains('cancel') ||
            status.contains('expire') ||
            status.contains('failure')) {
          _statusTimer?.cancel();
          if (mounted) {
            widget.onPaymentComplete(false);
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[PaymentWebView] poll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
