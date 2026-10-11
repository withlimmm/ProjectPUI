import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  StreamSubscription<DatabaseEvent>? _firebaseSub;

  // Estimasi cerdas per fase
  String _estimasiLabel = 'Estimasi Tiba';
  String _estimasiNilai = 'Menghitung...';
  String _durasiFaseIcon = 'clock';

  // Paket info dari API
  String _durasicuci = '';

  // Koordinat Peta
  LatLng _customerLocation = const LatLng(-7.732196, 110.340922);
  LatLng _courierLocation = const LatLng(-7.751452, 110.351935);
  LatLng _tokoLocation = const LatLng(-7.751452, 110.351935);
  bool _hasRealCourierCoords = false;
  List<LatLng> _routePoints = [];
  LatLng? _lastRouteCourierPos;

  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.status;
    _updateEstimasi();
    _fetchRealtimeData();

    // 1. Polling API Database setiap 4 detik untuk memastikan status selalu sinkron
    _apiTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchRealtimeData();
    });

    // 2. Firebase Realtime Database: Dengarkan koordinat GPS asli kurir secara instan!
    final rawId = widget.orderId.split('-').last;
    final orderNum = int.tryParse(rawId) ?? 0;

    _firebaseSub = FirebaseDatabase.instance
        .ref()
        .child('tracking')
        .child(orderNum.toString())
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        bool moved = false;

        if (data['kurir_lat'] != null && data['kurir_lng'] != null) {
          final lat = double.tryParse(data['kurir_lat'].toString());
          final lng = double.tryParse(data['kurir_lng'].toString());
          if (lat != null && lng != null) {
            setState(() {
              _courierLocation = LatLng(lat, lng);
              _hasRealCourierCoords = true;
            });
            moved = true;
          }
        }

        if (data['status'] != null && data['status'].toString().isNotEmpty) {
          final newSt = data['status'].toString();
          if (newSt != currentStatus) {
            setState(() {
              currentStatus = newSt;
            });
            _updateEstimasi();
          }
        }

        if (moved || _routePoints.isEmpty) {
          _fetchRoute(_courierLocation, _customerLocation);
        }
      }
    });
  }

  @override
  void dispose() {
    _apiTimer?.cancel();
    _firebaseSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // --- HITUNG TINGKAT FASE PESANAN (1 s/d 4) ---
  int _getStepLevel(String st) {
    final s = st.toLowerCase().trim();
    if (s.contains('selesai')) return 4;
    if (s.contains('antar') || s.contains('siap')) return 3;
    if (s.contains('cuci') || s.contains('proses')) return 2;
    // Level 1: Menunggu Konfirmasi, Menunggu Penjemputan, Kurir Menuju Lokasi, Tiba di Lokasi
    return 1;
  }

  // --- HITUNG JARAK HAVERSINE (dalam km) ---
  double _hitungJarakKm(LatLng a, LatLng b) {
    double deltaLat = (b.latitude - a.latitude) * 111.0;
    double deltaLng = (b.longitude - a.longitude) *
        111.0 *
        _cosApprox((a.latitude + b.latitude) / 2);
    double jarak = (deltaLat * deltaLat + deltaLng * deltaLng);
    jarak = jarak < 0 ? 0 : jarak;
    return (jarak == 0 ? 0 : _sqrt(jarak)) * 1.3;
  }

  double _cosApprox(double deg) {
    double r = deg * 3.14159 / 180;
    return 1 - (r * r / 2);
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x / 2;
    for (int i = 0; i < 20; i++) {
      z = (z + x / z) / 2;
    }
    return z;
  }

  // --- UPDATE ESTIMASI PER FASE ---
  void _updateEstimasi() {
    String st = currentStatus.toLowerCase();

    if (st.contains('selesai')) {
      _estimasiLabel = 'Pesanan Selesai';
      _estimasiNilai = 'Sudah diterima';
      _durasiFaseIcon = 'done';
      return;
    }

    if (st.contains('diantar')) {
      double jarakKm = _hitungJarakKm(_courierLocation, _customerLocation);
      int menitTiba = (jarakKm / 30 * 60).ceil().clamp(3, 120);
      _estimasiLabel = 'Estimasi Tiba';
      _estimasiNilai = '$menitTiba menit';
      _durasiFaseIcon = 'delivery';
      return;
    }

    if (st.contains('siap')) {
      _estimasiLabel = 'Pakaian Siap Diantar';
      _estimasiNilai = 'Menunggu Kurir';
      _durasiFaseIcon = 'delivery';
      return;
    }

    if (st.contains('dicuci') || st.contains('proses') || st.contains('cuci')) {
      String durasi = _durasicuci.isNotEmpty ? _durasicuci : '1 - 2 Hari';
      _estimasiLabel = 'Estimasi Selesai Cuci';
      _estimasiNilai = durasi;
      _durasiFaseIcon = 'wash';
      return;
    }

    if (st.contains('tiba')) {
      _estimasiLabel = 'Status Kurir';
      _estimasiNilai = 'Tiba di Lokasi Jemput';
      _durasiFaseIcon = 'pickup';
      return;
    }

    // Default fase penjemputan
    double jarakKm = _hitungJarakKm(_courierLocation, _customerLocation);
    int menitJemput = (jarakKm / 25 * 60).ceil().clamp(3, 120);
    _estimasiLabel = 'Estimasi Kurir Tiba';
    _estimasiNilai = '$menitJemput menit';
    _durasiFaseIcon = 'pickup';
  }

  // --- FUNGSI MENGAMBIL RUTE (GARIS BIRU) OSRM ---
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    // 1. Fallback instan: Pasang garis langsung agar garis rute PASTI muncul
    if (_routePoints.isEmpty) {
      if (mounted) {
        setState(() {
          _routePoints = [start, end];
        });
      }
    }

    if (_lastRouteCourierPos != null) {
      final distance =
          const Distance().as(LengthUnit.Meter, _lastRouteCourierPos!, start);
      if (distance < 15 && _routePoints.length > 2) return;
    }

    try {
      // Gunakan HTTPS agar tidak dicegat oleh Android Cleartext Traffic policy
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'];
        if (routes != null && routes.isNotEmpty) {
          final coords = routes[0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() {
              _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
              _lastRouteCourierPos = start;

              double durationSec = (routes[0]['duration'] ?? 0).toDouble();
              int menitTiba = (durationSec / 60).ceil();
              if (menitTiba < 1) menitTiba = 1;
              _estimasiNilai = '$menitTiba menit (Live)';
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch OSRM rute: $e");
      if (mounted && _routePoints.isEmpty) {
        setState(() {
          _routePoints = [start, end];
        });
      }
    }
  }

  // --- FUNGSI MENGAMBIL DATA TERBARU DARI DATABASE ---
  Future<void> _fetchRealtimeData() async {
    try {
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

              // Ambil koordinat pelanggan
              double? custLat =
                  double.tryParse(data['customer_lat']?.toString() ?? '');
              double? custLng =
                  double.tryParse(data['customer_lng']?.toString() ?? '');
              if (custLat != null && custLng != null) {
                _customerLocation = LatLng(custLat, custLng);
              }

              // Ambil koordinat toko
              double? tokoLat =
                  double.tryParse(data['toko_lat']?.toString() ?? '');
              double? tokoLng =
                  double.tryParse(data['toko_lng']?.toString() ?? '');
              if (tokoLat != null && tokoLng != null) {
                _tokoLocation = LatLng(tokoLat, tokoLng);
              }

              // Ambil koordinat kurir dari database jika Firebase belum terkoneksi
              double? kLat =
                  double.tryParse(data['kurir_lat']?.toString() ?? '');
              double? kLng =
                  double.tryParse(data['kurir_lng']?.toString() ?? '');
              if (kLat != null && kLng != null && !_hasRealCourierCoords) {
                _courierLocation = LatLng(kLat, kLng);
                _hasRealCourierCoords = true;
              }

              // Posisi kurir saat fase cuci vs bergerak
              String st = (data['status'] ?? '').toLowerCase();
              if (st.contains('dicuci') || st.contains('proses')) {
                _courierLocation = _tokoLocation;
              } else if (!_hasRealCourierCoords) {
                _courierLocation = LatLng(
                  (_customerLocation.latitude + _tokoLocation.latitude) / 2,
                  (_customerLocation.longitude + _tokoLocation.longitude) / 2,
                );
              }

              if (data['durasi_label'] != null) {
                _durasicuci = data['durasi_label'];
              }

              if (data['nama_kurir'] != null) {
                namaKurir = data['nama_kurir'];
                String kendaraan = data['kendaraan'] ?? 'Motor';
                String plat = data['plat_nomor'] ?? '';
                kendaraanKurir = plat.isNotEmpty ? '$kendaraan ($plat)' : kendaraan;
                hpKurir = data['hp_kurir'] ?? '';
              }

              _updateEstimasi();
            });

            _fetchRoute(_courierLocation, _customerLocation);
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal tarik data realtime: $e");
    }
  }

  // --- FUNGSI HUBUNGI KURIR ---
  Future<void> _hubungiKurir(String jenis) async {
    if (hpKurir.isEmpty && jenis != 'chat') {
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
    final int stepLevel = _getStepLevel(currentStatus);

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
          // 1. BAGIAN PETA & GARIS RUTE REALTIME
          // ==========================================
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _courierLocation,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rakiradigital.pintpoint',
                    ),
                    // GARIS RUTE BIRU REALTIME
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.5,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Marker Lokasi Pelanggan
                        Marker(
                          point: _customerLocation,
                          width: 45,
                          height: 45,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 42,
                          ),
                        ),
                        // Marker Toko Pint Point
                        Marker(
                          point: _tokoLocation,
                          width: 48,
                          height: 48,
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
                              size: 24,
                            ),
                          ),
                        ),
                        // Marker Kurir Bergerak Realtime
                        if (!lowerStatus.contains('dicuci') &&
                            !lowerStatus.contains('proses'))
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
                                        : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6),
                                ],
                              ),
                              child: Icon(
                                lowerStatus.contains('diantar')
                                    ? Icons.local_shipping
                                    : lowerStatus.contains('selesai')
                                        ? Icons.check
                                        : Icons.motorcycle,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Kartu Estimasi Tiba Mengambang
                Container(
                  margin: const EdgeInsets.only(
                    bottom: 15,
                    left: 20,
                    right: 20,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
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
                                      : Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _durasiFaseIcon == 'wash'
                              ? Icons.local_laundry_service
                              : _durasiFaseIcon == 'delivery'
                                  ? Icons.local_shipping
                                  : _durasiFaseIcon == 'done'
                                      ? Icons.check_circle
                                      : Icons.motorcycle,
                          color: _durasiFaseIcon == 'wash'
                              ? Colors.purple
                              : _durasiFaseIcon == 'delivery'
                                  ? Colors.orange
                                  : _durasiFaseIcon == 'done'
                                      ? Colors.green
                                      : const Color(0xFF2563EB),
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
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
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
                            color: Color(0xFF2563EB),
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

          // ==========================================
          // 2. KARTU PROFIL KURIR & TIMELINE STATUS
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
                    _buildFaseCard(lowerStatus),
                    const SizedBox(height: 25),

                    const Text(
                      'Status Pesanan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // STEP 1: Penjemputan (Menunggu Konfirmasi / Jemput / OTW / Tiba)
                    _buildTimelineTile(
                      icon: Icons.motorcycle,
                      title: 'Menunggu Penjemputan',
                      subtitle: currentStatus == 'Kurir Menuju Lokasi'
                          ? 'Kurir sedang dalam perjalanan ke lokasi Anda'
                          : currentStatus == 'Tiba di Lokasi'
                              ? 'Kurir telah tiba di lokasi penjemputan'
                              : 'Kurir bersiap menuju lokasi penjemputan',
                      isActive: stepLevel >= 1,
                      isCompleted: stepLevel > 1,
                      isCurrentProcess: stepLevel == 1,
                      activeColor: const Color(0xFF2563EB),
                      badgeText: currentStatus == 'Kurir Menuju Lokasi'
                          ? 'Kurir OTW ke lokasi Anda'
                          : currentStatus == 'Tiba di Lokasi'
                              ? 'Kurir tiba di lokasi jemput'
                              : 'Menunggu penjemputan',
                    ),

                    // STEP 2: Pencucian (Admin / Laundry)
                    _buildTimelineTile(
                      icon: Icons.local_laundry_service_outlined,
                      title: 'Pakaian Sedang Dicuci',
                      subtitle:
                          'Pakaian Anda sedang dalam proses pencucian & perawatan',
                      isActive: stepLevel >= 2,
                      isCompleted: stepLevel > 2,
                      isCurrentProcess: stepLevel == 2,
                      activeColor: Colors.purple,
                      badgeText: 'Pakaian sedang dicuci oleh laundry',
                    ),

                    // STEP 3: Pengantaran (Admin siapkan, Kurir antar)
                    _buildTimelineTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Pakaian Siap Diantar',
                      subtitle: lowerStatus.contains('diantar')
                          ? 'Kurir dalam perjalanan mengantar pakaian ke rumah Anda'
                          : 'Pakaian selesai dicuci dan siap diantar oleh kurir',
                      isActive: stepLevel >= 3,
                      isCompleted: stepLevel > 3,
                      isCurrentProcess: stepLevel == 3,
                      activeColor: Colors.orange,
                      badgeText: lowerStatus.contains('diantar')
                          ? 'Kurir sedang mengantar pakaian'
                          : 'Pakaian siap diantar',
                    ),

                    // STEP 4: Selesai
                    _buildTimelineTile(
                      icon: Icons.check_circle_outline,
                      title: 'Selesai',
                      subtitle: 'Pakaian telah diterima oleh pelanggan',
                      isActive: stepLevel >= 4,
                      isCompleted: stepLevel >= 4,
                      isCurrentProcess: false,
                      isLast: true,
                      activeColor: Colors.green,
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

  // ============================================================
  // WIDGET STEP TIMELINE DENGAN WARNA DINAMIS
  // ============================================================
  Widget _buildTimelineTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    bool isCurrentProcess = false,
    bool isLast = false,
    Color activeColor = const Color(0xFF2563EB),
    String? badgeText,
  }) {
    Color circleColor;
    Color iconColor = Colors.white;
    IconData displayIcon = icon;

    if (isCompleted) {
      circleColor = Colors.green;
      displayIcon = Icons.check;
    } else if (isActive) {
      circleColor = activeColor;
    } else {
      circleColor = Colors.grey.shade200;
      iconColor = Colors.grey.shade400;
    }

    Color lineColor = isCompleted ? Colors.green : Colors.grey.shade300;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrentProcess
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(displayIcon, color: iconColor, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
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
                      color: isActive ? Colors.black87 : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  if (isCurrentProcess && badgeText != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: activeColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: activeColor,
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
    if (lowerStatus.contains('selesai')) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white, size: 28),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pesanan Selesai!',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 3),
                  Text('Pakaian telah diterima oleh pelanggan',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
                namaKurir.isNotEmpty
                    ? namaKurir.substring(0, 1).toUpperCase()
                    : 'K',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    namaKurir.contains('Mencari')
                        ? 'Kurir Mengantar'
                        : namaKurir,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    kendaraanKurir == '-'
                        ? 'Sedang menuju lokasi Anda'
                        : kendaraanKurir,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

    if (lowerStatus.contains('dicuci') ||
        lowerStatus.contains('proses') ||
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
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    'Pakaian sedang dicuci - Estimasi: $_estimasiNilai',
                    style:
                        TextStyle(color: Colors.purple.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

    // Default fase jemput
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
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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