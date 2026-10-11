import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../../../core/services/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../chat/chat_screen.dart';
import 'courier_printer_screen.dart';

class DetailNavigasiPage extends StatefulWidget {
  final Map<String, dynamic> tugas;

  const DetailNavigasiPage({super.key, required this.tugas});

  @override
  _DetailNavigasiPageState createState() => _DetailNavigasiPageState();
}

class _DetailNavigasiPageState extends State<DetailNavigasiPage> {
  late String currentStatus;
  bool isLoading = false;

  // Variabel Live Tracking Realtime
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationTimer;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.tugas['status'] ?? 'Menunggu Penjemputan';

    // Broadcast GPS kurir selama tugas aktif
    if (currentStatus != 'Selesai' &&
        currentStatus != 'Diterima Laundry' &&
        currentStatus != 'Sedang Dicuci' &&
        currentStatus != 'Menunggu Pembayaran') {
      _startTracking();
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final String orderId = widget.tugas['id'].toString();

    try {
      Position firstPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _kirimLokasiKurir(firstPos, orderId);
    } catch (_) {}

    _positionStreamSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) _kirimLokasiKurir(position, orderId);
    });

    _locationTimer ??= Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (!mounted || currentStatus == 'Selesai') {
        timer.cancel();
        return;
      }
      try {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _kirimLokasiKurir(pos, orderId);
      } catch (_) {}
    });
  }

  void _kirimLokasiKurir(Position pos, String orderId) {
    if (!mounted) return;
    _dbRef.child('tracking').child(orderId).set({
      'kurir_lat': pos.latitude,
      'kurir_lng': pos.longitude,
      'status': currentStatus,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    http.post(
      Uri.parse('$apiUrl/kurir/update-location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'is_online': true,
      }),
    ).onError((_, __) => http.Response('', 500));
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> bukaPetunjukJalan(double lat, double lng) async {
    final String googleMapsUrl = "google.navigation:q=$lat,$lng&mode=d";
    final Uri googleUri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri);
    } else {
      final Uri webUri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // --- FUNGSI UPDATE STATUS DENGAN VALIDASI LOGIKA ---
  Future<void> updateStatus(String statusBaru) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final kurirId = prefs.getString('user_id');
      final String orderId = widget.tugas['id'].toString();
      final url = Uri.parse('$apiUrl/kurir/update-status/$orderId');

      final response = await http
          .post(url, body: {
            'status_baru': statusBaru,
            if (kurirId != null) 'kurir_id': kurirId,
          })
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            currentStatus = statusBaru;
            isLoading = false;
          });

          // Hentikan tracking jika sudah diserahkan ke toko atau selesai
          if (statusBaru == 'Selesai' || statusBaru == 'Diterima Laundry') {
            _stopTracking();
          } else {
            _startTracking();
          }

          _dbRef.child('tracking').child(orderId).update({
            'status': statusBaru,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Berhasil: $statusBaru"),
              backgroundColor: Colors.green,
            ),
          );

          // Jika cucian sudah diserahkan ke laundry, tugas penjemputan selesai bagi kurir
          if (statusBaru == 'Diterima Laundry') {
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) Navigator.pop(context, true);
          }
        }
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? "Gagal update status");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- FUNGSI UPLOAD BUKTI SERAH TERIMA PENGANTARAN ---
  Future<void> _uploadBuktiDanSelesai() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) return;

    setState(() => isLoading = true);

    try {
      final String orderId = widget.tugas['id'].toString();
      final url = Uri.parse('$apiUrl/kurir/selesaikan/$orderId');

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('bukti', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            currentStatus = 'Selesai';
            isLoading = false;
          });
          _stopTracking();

          _dbRef.child('tracking').child(orderId).update({
            'status': 'Selesai',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pengantaran berhasil diselesaikan!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? "Gagal menyelesaikan pengantaran");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- DETEKSI TIPE TUGAS & PEMBAYARAN ---
  bool get isFaseJemput {
    final s = currentStatus.toLowerCase();
    return s.contains('konfirmasi') ||
        s.contains('kurir') ||
        s.contains('jemput') ||
        s.contains('menuju lokasi') ||
        s.contains('tiba di lokasi');
  }

  bool get isFaseDiLaundry {
    final s = currentStatus.toLowerCase();
    return s.contains('diterima laundry') ||
        s.contains('cuci') ||
        s.contains('pembayaran');
  }

  bool get isFaseAntar {
    final s = currentStatus.toLowerCase();
    return s.contains('siap') || s.contains('antar');
  }

  bool get isCOD {
    final method = (widget.tugas['payment_method'] ?? '').toString().toLowerCase();
    return method == 'cod';
  }

  bool get isLunas {
    final payStatus = (widget.tugas['payment_status'] ?? '').toString().toLowerCase();
    return payStatus == 'paid' ||
        payStatus == 'paid_cod' ||
        payStatus == 'cod_confirmed' ||
        payStatus == 'settlement' ||
        payStatus == 'capture';
  }

  int get totalHarga {
    return (double.tryParse(widget.tugas['total_harga']?.toString() ?? '0') ?? 0).toInt();
  }

  @override
  Widget build(BuildContext context) {
    double lat = double.tryParse(widget.tugas['latitude']?.toString() ?? '-7.7956') ?? -7.7956;
    double lng = double.tryParse(widget.tugas['longitude']?.toString() ?? '110.3695') ?? 110.3695;
    LatLng lokasiPelanggan = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text("Navigasi ${widget.tugas['id_pesanan'] ?? ''}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.blue),
            tooltip: 'Cetak Struk',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourierPrinterScreen(orderData: widget.tugas),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // MAPS VIEW
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: lokasiPelanggan,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rakiradigital.pintpoint',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: lokasiPelanggan,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 50,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton.extended(
                    onPressed: () => bukaPetunjukJalan(lat, lng),
                    backgroundColor: Colors.blue[800],
                    icon: const Icon(Icons.navigation, color: Colors.white),
                    label: const Text(
                      "Buka Petunjuk Jalan",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PANEL DETAIL TUGAS & TOMBOL AKSI
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BADGE INDIKATOR TUGAS & PEMBAYARAN (AGAR KURIR TIDAK BINGUNG) ---
                  Row(
                    children: [
                      // Badge Jenis Tugas
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isFaseJemput
                              ? Colors.orange.shade50
                              : isFaseDiLaundry
                                  ? Colors.purple.shade50
                                  : isFaseAntar
                                      ? Colors.blue.shade50
                                      : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFaseJemput
                                ? Colors.orange.shade300
                                : isFaseDiLaundry
                                    ? Colors.purple.shade300
                                    : isFaseAntar
                                        ? Colors.blue.shade300
                                        : Colors.green.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isFaseJemput
                                  ? Icons.shopping_bag_outlined
                                  : isFaseDiLaundry
                                      ? Icons.local_laundry_service
                                      : isFaseAntar
                                          ? Icons.delivery_dining
                                          : Icons.check_circle_outline,
                              size: 14,
                              color: isFaseJemput
                                  ? Colors.orange.shade800
                                  : isFaseDiLaundry
                                      ? Colors.purple.shade800
                                      : isFaseAntar
                                          ? Colors.blue.shade800
                                          : Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFaseJemput
                                  ? "TUGAS JEMPUT"
                                  : isFaseDiLaundry
                                      ? "DI LAUNDRY (PROSES CUCI)"
                                      : isFaseAntar
                                          ? "TUGAS ANTAR"
                                          : "SELESAI",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isFaseJemput
                                    ? Colors.orange.shade800
                                    : isFaseDiLaundry
                                        ? Colors.purple.shade800
                                        : isFaseAntar
                                            ? Colors.blue.shade800
                                            : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Badge Pembayaran (COD vs Lunas)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isCOD && !isLunas)
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isCOD && !isLunas)
                                ? Colors.red.shade300
                                : Colors.green.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (isCOD && !isLunas) ? Icons.payments_outlined : Icons.check_circle,
                              size: 14,
                              color: (isCOD && !isLunas) ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (isCOD && !isLunas)
                                  ? "COD: Rp ${NumberFormat('#,###', 'id_ID').format(totalHarga)}"
                                  : "LUNAS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (isCOD && !isLunas) ? Colors.red.shade800 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Alamat Pelanggan
                  const Text(
                    "Alamat Pelanggan",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    widget.tugas['alamat'] ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Waktu: ${widget.tugas['tanggal_jemput']} | ${widget.tugas['waktu_jemput']}",
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const Divider(height: 20),

                  // Info Pelanggan & Chat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.person, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.tugas['nama_pelanggan'] ?? 'Pelanggan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () {
                              final noHp = widget.tugas['no_hp_pelanggan'];
                              if (noHp != null && noHp != '-') {
                                launchUrl(Uri.parse('tel:$noHp'));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    orderId: widget.tugas['id_pesanan'].toString(),
                                    receiverName: widget.tugas['nama_pelanggan'] ?? 'Pelanggan',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // --- BANNER INFO JIKA PESANAN SEDANG DI WORKSHOP LAUNDRY ---
                  if (isFaseDiLaundry)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.purple, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Cucian sedang dicuci di toko. Tunggu hingga Admin mengubah status menjadi 'Siap Diantar' untuk mengantar.",
                              style: TextStyle(fontSize: 11, color: Colors.purple),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // --- TOMBOL AKSI KURIR SESUAI LOGIKA BISNIS ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(currentStatus),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: (isLoading || isFaseDiLaundry || currentStatus == 'Selesai')
                          ? null
                          : () {
                              if (currentStatus == "Menunggu Konfirmasi" ||
                                  currentStatus == "Menunggu Penjemputan") {
                                updateStatus("Kurir Menuju Lokasi");
                              } else if (currentStatus == "Kurir Menuju Lokasi") {
                                updateStatus("Tiba di Lokasi");
                              } else if (currentStatus == "Tiba di Lokasi") {
                                // Pakaian diambil, kurir menyerahkan ke laundry
                                updateStatus("Diterima Laundry");
                              } else if (currentStatus == "Siap Diantar" ||
                                  currentStatus == "Pakaian Siap Diantar") {
                                updateStatus("Diantar");
                              } else if (currentStatus == "Diantar") {
                                _uploadBuktiDanSelesai();
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _getButtonText(currentStatus),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText(String status) {
    switch (status) {
      case "Menunggu Konfirmasi":
      case "Menunggu Penjemputan":
        return "Mulai Jalan Jemput Pakaian";
      case "Kurir Menuju Lokasi":
        return "Tiba di Rumah Pelanggan";
      case "Tiba di Lokasi":
        return "Ambil Pakaian & Serahkan ke Laundry";
      case "Diterima Laundry":
      case "Menunggu Pembayaran":
      case "Sedang Dicuci":
        return "Sedang Diproses Toko Laundry";
      case "Siap Diantar":
      case "Pakaian Siap Diantar":
        return "Mulai Antar ke Pelanggan";
      case "Diantar":
        return isCOD
            ? "Selesai (Tagih COD & Foto Bukti)"
            : "Selesai (Upload Foto Bukti)";
      case "Selesai":
        return "Tugas Telah Selesai";
      default:
        return "Update Status";
    }
  }

  Color _getButtonColor(String status) {
    if (status == "Kurir Menuju Lokasi") return Colors.orange.shade700;
    if (status == "Tiba di Lokasi") return Colors.green.shade700;
    if (status == "Siap Diantar" || status == "Pakaian Siap Diantar") return const Color(0xFF00A2E9);
    if (status == "Diantar") return Colors.deepPurple;
    if (status == "Diterima Laundry" || status == "Sedang Dicuci" || status == "Menunggu Pembayaran") {
      return Colors.grey.shade400;
    }
    return AppColors.primary;
  }
}