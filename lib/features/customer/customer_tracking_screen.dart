import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/services/api_config.dart';
import '../chat/chat_screen.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String orderId;
  final String status;

  const CustomerTrackingScreen({
    super.key,
    required this.orderId,
    required this.status,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final MapController _mapController = MapController();

  // Data Dinamis dari Database
  String currentStatus = "";
  String namaKurir = "Mencari Kurir...";
  String kendaraanKurir = "-";
  String hpKurir = "";

  Timer? _apiTimer;
  Timer? _animTimer;

  // Estimasi cerdas per fase (seperti GrabFood)
  String _estimasiLabel  = 'Estimasi Tiba';  // label atas
  String _estimasiNilai  = 'Menghitung...';  // nilai bawah
  String _durasiFaseIcon = 'clock';          // ikon konteks

  // Paket info dari API
  String _durasicuci = '';

  // Koordinat Peta - akan diisi dari API
  // Default: koordinat toko Pint Point (Sinduadi, Mlati, Sleman)
  LatLng _customerLocation = const LatLng(-7.732196, 110.340922);
  LatLng _courierLocation  = const LatLng(-7.751452, 110.351935); // Default = toko
  LatLng _tokoLocation     = const LatLng(-7.751452, 110.351935);
  bool   _hasRealCoords    = false;

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.status;
    _updateEstimasi(); // Langsung hitung estimasi dari status awal
    _fetchRealtimeData(); // Ambil data terbaru dari API

    // 1. Timer API: Cek status terbaru ke database setiap 5 detik
    _apiTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchRealtimeData();
    });

    // 2. Firebase Realtime Database: Dengarkan perubahan lokasi kurir secara instan!
    FirebaseDatabase.instance
        .ref()
        .child('tracking')
        .child(widget.orderId.toString())
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        if (mounted && data['kurir_lat'] != null && data['kurir_lng'] != null) {
          setState(() {
            _courierLocation = LatLng(
              double.parse(data['kurir_lat'].toString()),
              double.parse(data['kurir_lng'].toString())
            );
          });
          print("Peta Pelanggan Diperbarui: ${_courierLocation.latitude}, ${_courierLocation.longitude}");
        }
      }
    });
  }

  // --- HITUNG JARAK HAVERSINE (dalam km) ---
  double _hitungJarakKm(LatLng a, LatLng b) {
    const double R = 6371; // radius bumi km
    double dLat = _toRad(b.latitude  - a.latitude);
    double dLng = _toRad(b.longitude - a.longitude);
    double h = (dLat / 2).abs() < 0.001 && (dLng / 2).abs() < 0.001
        ? 0
        : 0;
    // Simplified: lurus * 1.3 koreksi jalan
    double deltaLat = (b.latitude  - a.latitude)  * 111.0;
    double deltaLng = (b.longitude - a.longitude) * 111.0 *
        _cosApprox((a.latitude + b.latitude) / 2);
    double jarak = (deltaLat * deltaLat + deltaLng * deltaLng);
    jarak = jarak < 0 ? 0 : jarak;
    return (jarak == 0 ? 0 : _sqrt(jarak)) * 1.3; // koreksi jalan
  }

  double _toRad(double deg) => deg * 3.14159 / 180;
  double _cosApprox(double deg) {
    double r = deg * 3.14159 / 180;
    return 1 - (r * r / 2); // Taylor approx cos
  }
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x / 2;
    for (int i = 0; i < 20; i++) z = (z + x / z) / 2;
    return z;
  }

  // --- UPDATE ESTIMASI PER FASE ---
  void _updateEstimasi() {
    String st = currentStatus.toLowerCase();

    if (st.contains('selesai')) {
      _estimasiLabel = 'Pesanan Selesai';
      _estimasiNilai = '🎉 Sudah diterima';
      _durasiFaseIcon = 'done';
      return;
    }

    if (st.contains('diantar')) {
      // Fase antar: hitung jarak toko → pelanggan
      double jarakKm = _hitungJarakKm(_tokoLocation, _customerLocation);
      int menitTiba  = (jarakKm / 30 * 60).ceil().clamp(3, 120);
      _estimasiLabel = 'Estimasi Tiba';
      _estimasiNilai = '$menitTiba menit';
      _durasiFaseIcon = 'delivery';
      return;
    }

    if (st.contains('dicuci') || st.contains('proses')) {
      // Fase cuci: tampilkan durasi paket (2 Hari / 24 Jam / dll)
      String durasi = _durasicuci.isNotEmpty ? _durasicuci : '1–2 Hari';
      _estimasiLabel = 'Estimasi Selesai Cuci';
      _estimasiNilai = durasi;
      _durasiFaseIcon = 'wash';
      return;
    }

    // Fase jemput (default): hitung jarak toko → pelanggan
    double jarakKm  = _hitungJarakKm(_tokoLocation, _customerLocation);
    int menitJemput = (jarakKm / 25 * 60).ceil().clamp(3, 120);
    _estimasiLabel = 'Estimasi Kurir Tiba';
    _estimasiNilai = '$menitJemput menit';
    _durasiFaseIcon = 'pickup';
  }

  @override
  void dispose() {
    _apiTimer?.cancel();
    _animTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- FUNGSI MENGAMBIL DATA KURIR ASLI DARI DATABASE ---
  Future<void> _fetchRealtimeData() async {
    try {
      // Ekstrak ID asli (contoh: dari PP-2026002 menjadi 2)
      String rawId = widget.orderId.split('-').last;
      int dbId = int.parse(rawId);

      final response = await http.get(
        Uri.parse('$apiUrl/pesanan/tracking/$dbId'),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        if (res['status'] == 'success') {
          var data = res['data'];
          if (mounted) {
            setState(() {
              currentStatus = data['status'] ?? currentStatus;

              // Ambil koordinat pelanggan (lokasi jemput asli)
              double? custLat = double.tryParse(data['customer_lat']?.toString() ?? '');
              double? custLng = double.tryParse(data['customer_lng']?.toString() ?? '');
              if (custLat != null && custLng != null) {
                _customerLocation = LatLng(custLat, custLng);
                _hasRealCoords = true;
              }

              // Ambil koordinat toko dari settings
              double? tokoLat = double.tryParse(data['toko_lat']?.toString() ?? '');
              double? tokoLng = double.tryParse(data['toko_lng']?.toString() ?? '');
              if (tokoLat != null && tokoLng != null) {
                _tokoLocation = LatLng(tokoLat, tokoLng);
              }

              // Atur posisi kurir:
              // - Saat Dicuci/Proses → kurir ada di toko
              // - Saat menjemput/mengantar → kurir di antara pelanggan & toko
              String st = (data['status'] ?? '').toLowerCase();
              if (st.contains('dicuci') || st.contains('proses')) {
                _courierLocation = _tokoLocation;
              } else if (!_hasRealCoords || _courierLocation == _tokoLocation) {
                // Set default kurir di antara toko dan pelanggan
                _courierLocation = LatLng(
                  (_customerLocation.latitude + _tokoLocation.latitude) / 2,
                  (_customerLocation.longitude + _tokoLocation.longitude) / 2,
                );
              }

              // Simpan durasi cuci dari paket
              if (data['durasi_label'] != null) {
                _durasicuci = data['durasi_label'];
              }

              // Jika kurir sudah ditugaskan, tampilkan datanya!
              if (data['nama_kurir'] != null) {
                namaKurir = data['nama_kurir'];
                String kendaraan = data['kendaraan'] ?? 'Motor';
                String plat = data['plat_nomor'] ?? '';
                kendaraanKurir = '$kendaraan ($plat)';
                hpKurir = data['hp_kurir'] ?? '';
              }

              // Hitung estimasi cerdas setelah semua data tersedia
              _updateEstimasi();
            });

            // Center peta ke lokasi pelanggan
            try {
              _mapController.move(_customerLocation, 14.0);
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal tarik data realtime: $e");
    }
  }

  // --- FUNGSI TELEPON & WHATSAPP ASLI KE NOMOR KURIR ---
  Future<void> _hubungiKurir(String jenis) async {
    if (hpKurir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor kurir belum tersedia')),
      );
      return;
    }

    if (jenis == 'chat') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            orderId: widget.orderId,
            receiverName: namaKurir,
          ),
        ),
      );
      return;
    }

    // Ubah nomor awalan 0 menjadi 62 untuk WhatsApp/Telepon
    String formattedPhone = hpKurir;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }

    final Uri url = Uri.parse('tel:+$formattedPhone');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi telepon.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String lowerStatus = currentStatus.toLowerCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6F9),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lacak Pesanan',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.orderId,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. BAGIAN PETA & FLOATING ESTIMASI TINGGI
          // ==========================================
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _tokoLocation,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pintpoint.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _customerLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ),
                        // --- Marker Toko Pint Point ---
                        Marker(
                          point: _tokoLocation,
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 5),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_laundry_service,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                        // --- Marker berubah sesuai status ---
                        if (!lowerStatus.contains('dicuci') && !lowerStatus.contains('proses'))
                          Marker(
                            point: _courierLocation,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: lowerStatus.contains('diantar')
                                    ? Colors.orange
                                    : lowerStatus.contains('selesai')
                                        ? Colors.green
                                        : Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 5),
                                ],
                              ),
                              child: Icon(
                                lowerStatus.contains('diantar')
                                    ? Icons.local_shipping
                                    : lowerStatus.contains('selesai')
                                        ? Icons.check
                                        : Icons.motorcycle,
                                color: Colors.white,
                                size: 25,
                              ),
                            ),
                          ),
                        // --- Marker mesin cuci saat dicuci ---
                        if (lowerStatus.contains('dicuci') || lowerStatus.contains('proses'))
                          Marker(
                            point: _customerLocation,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.purple.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 5),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_laundry_service,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                Container(
                  margin: const EdgeInsets.only(
                    bottom: 15,
                    left: 20,
                    right: 20,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _durasiFaseIcon == 'wash'
                              ? Colors.purple.shade50
                              : _durasiFaseIcon == 'delivery'
                                  ? Colors.orange.shade50
                                  : _durasiFaseIcon == 'done'
                                      ? Colors.green.shade50
                                      : Colors.blue.shade50, // pickup / clock
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _durasiFaseIcon == 'wash'
                              ? Icons.local_laundry_service
                              : _durasiFaseIcon == 'delivery'
                                  ? Icons.local_shipping
                                  : _durasiFaseIcon == 'done'
                                      ? Icons.check_circle
                                      : Icons.motorcycle, // pickup
                          color: _durasiFaseIcon == 'wash'
                              ? Colors.purple
                              : _durasiFaseIcon == 'delivery'
                                  ? Colors.orange
                                  : _durasiFaseIcon == 'done'
                                      ? Colors.green
                                      : Colors.blue, // pickup
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _estimasiLabel,
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _estimasiNilai,
                              style: TextStyle(
                                fontSize: _durasiFaseIcon == 'wash' ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: _durasiFaseIcon == 'wash'
                                    ? Colors.purple.shade700
                                    : _durasiFaseIcon == 'delivery'
                                        ? Colors.orange.shade700
                                        : _durasiFaseIcon == 'done'
                                            ? Colors.green.shade700
                                            : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _hubungiKurir('telpon'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _hubungiKurir('chat'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. KARTU PROFIL KURIR DINAMIS & TIMELINE
          // ==========================================
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KARTU INFO DINAMIS SESUAI FASE PESANAN
                    _buildFaseCard(lowerStatus),
                    const SizedBox(height: 25),

                    // TIMELINE STATUS TERINTEGRASI
                    const Text(
                      'Status Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildTimelineTile(
                      icon: Icons.access_time,
                      title: 'Menunggu Penjemputan',
                      subtitle: 'Kurir dalam perjalanan ke lokasi Anda',
                      isActive:
                          lowerStatus.contains('dijemput') ||
                          lowerStatus.contains('proses') ||
                          lowerStatus.contains('dicuci') ||
                          lowerStatus.contains('diantar') ||
                          lowerStatus.contains('selesai'),
                      isCompleted:
                          lowerStatus.contains('proses') ||
                          lowerStatus.contains('dicuci') ||
                          lowerStatus.contains('diantar') ||
                          lowerStatus.contains('selesai'),
                      isCurrentProcess: lowerStatus.contains('dijemput'),
                    ),
                    _buildTimelineTile(
                      icon: Icons.local_laundry_service_outlined,
                      title: 'Pakaian Sedang Dicuci',
                      subtitle: 'Pakaian Anda sedang dalam proses laundry',
                      isActive:
                          lowerStatus.contains('proses') ||
                          lowerStatus.contains('dicuci') ||
                          lowerStatus.contains('diantar') ||
                          lowerStatus.contains('selesai'),
                      isCompleted:
                          lowerStatus.contains('diantar') ||
                          lowerStatus.contains('selesai'),
                      isCurrentProcess:
                          lowerStatus.contains('proses') ||
                          lowerStatus.contains('dicuci'),
                    ),
                    _buildTimelineTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Pakaian Siap Diantar',
                      subtitle: 'Kurir dalam perjalanan mengantar pakaian',
                      isActive:
                          lowerStatus.contains('diantar') ||
                          lowerStatus.contains('selesai'),
                      isCompleted: lowerStatus.contains('selesai'),
                      isCurrentProcess: lowerStatus.contains('diantar'),
                    ),
                    _buildTimelineTile(
                      icon: Icons.check_circle_outline,
                      title: 'Selesai',
                      subtitle: 'Pakaian telah diterima oleh pelanggan',
                      isActive: lowerStatus.contains('selesai'),
                      isCompleted: lowerStatus.contains('selesai'),
                      isLast: true,
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

  Widget _buildTimelineTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    bool isCurrentProcess = false,
    bool isLast = false,
  }) {
    Color iconColor = isCompleted || isActive ? Colors.white : Colors.grey;
    Color circleColor = isCompleted || isActive
        ? Colors.blue
        : Colors.grey.shade200;
    Color lineColor = isCompleted ? Colors.blue : Colors.grey.shade300;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isActive ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (isCurrentProcess) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Sedang berlangsung...',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU INFO DINAMIS - BERUBAH SESUAI FASE PESANAN
  // ============================================================
  Widget _buildFaseCard(String lowerStatus) {
    // ─── FASE: SELESAI ───
    if (lowerStatus.contains('selesai')) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 15),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pesanan Selesai! 🎉',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 3),
                  Text('Pakaian telah diterima oleh pelanggan',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Selesai',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // ─── FASE: DIANTAR ───
    if (lowerStatus.contains('diantar')) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.orange,
              child: Text(
                namaKurir.isNotEmpty ? namaKurir.substring(0, 1).toUpperCase() : 'K',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    namaKurir.contains('Mencari') ? 'Kurir Mengantar' : namaKurir,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    kendaraanKurir == '-' ? 'Sedang menuju lokasi Anda' : kendaraanKurir,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Diantar',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // ─── FASE: DICUCI / PROSES ───
    if (lowerStatus.contains('dicuci') || lowerStatus.contains('proses') ||
        lowerStatus.contains('cuci')) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          border: Border.all(color: Colors.purple.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.purple.shade400,
              child: const Icon(Icons.local_laundry_service,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pint Point Laundry',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    'Pakaian sedang dicuci — Estimasi: $_estimasiNilai',
                    style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Proses',
                  style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // ─── FASE: JEMPUT / DEFAULT ───
    final bool kurirSudahDiketahui =
        namaKurir.isNotEmpty && !namaKurir.contains('Mencari');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: kurirSudahDiketahui ? Colors.blue : Colors.grey,
            child: kurirSudahDiketahui
                ? Text(
                    namaKurir.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  )
                : const Icon(Icons.search, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kurirSudahDiketahui ? namaKurir : 'Sedang Mencari Kurir',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  kurirSudahDiketahui
                      ? kendaraanKurir
                      : 'Harap tunggu, kurir akan segera ditemukan',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kurirSudahDiketahui
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              kurirSudahDiketahui ? 'Aktif' : 'Menunggu',
              style: TextStyle(
                  color: kurirSudahDiketahui
                      ? Colors.green
                      : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
