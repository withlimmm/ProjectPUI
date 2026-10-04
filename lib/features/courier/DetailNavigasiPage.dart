import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
// BARU: Import untuk Live Tracking & Chat
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

import '../../../core/services/api_config.dart';
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

  // Variabel Live Tracking
  StreamSubscription<Position>? _positionStreamSubscription;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // --- LOGIKA DETEKSI IP OTOMATIS ---
  String get apiUrl => apiBaseUrl;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.tugas['status'] ?? 'Menunggu Penjemputan';
    
    // Mulai tracking jika status saat ini sedang berjalan
    if (currentStatus == 'Dijemput' || currentStatus == 'Diantar') {
      _startTracking();
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  // --- FUNGSI LIVE TRACKING ---
  Future<void> _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final String orderId = widget.tugas['id'].toString();

    _positionStreamSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update setiap 10 meter untuk hemat baterai/kuota
      ),
    ).listen((Position position) {
      if (mounted) {
        _dbRef.child('tracking').child(orderId).set({
          'kurir_lat': position.latitude,
          'kurir_lng': position.longitude,
          'status': currentStatus,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        print("Live Tracking Update: ${position.latitude}, ${position.longitude}");
      }
    });
  }

  void _stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
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

  // --- FUNGSI UPDATE STATUS DENGAN TIMEOUT ---
  Future<void> updateStatus(String statusBaru) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final kurirId = prefs.getString('user_id');

      // Menggunakan id dari widget.tugas
      final String orderId = widget.tugas['id'].toString();
      final url = Uri.parse('$apiUrl/kurir/update-status/$orderId');

      final response = await http
          .post(url, body: {
            'status_baru': statusBaru,
            if (kurirId != null) 'kurir_id': kurirId,
          })
          .timeout(const Duration(seconds: 10)); // Batasi waktu tunggu 10 detik

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            currentStatus = statusBaru;
            isLoading = false;
          });
          
          // BARU: Kontrol Live Tracking berdasarkan status
          if (statusBaru == 'Dijemput' || statusBaru == 'Diantar') {
            _startTracking();
          } else {
            _stopTracking();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Berhasil: $statusBaru"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Gagal: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Koneksi gagal atau timeout. Periksa IP server."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- FUNGSI UPLOAD BUKTI COD ---
  Future<void> _uploadBuktiDanSelesai() async {
    final ImagePicker picker = ImagePicker();
    
    // [PENTING] Membuka kamera dengan kompresi otomatis agar ukuran foto < 1 MB
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,       // Kompres kualitas foto menjadi 60%
      maxWidth: 1200,         // Batasi resolusi lebar maksimal
      maxHeight: 1200,        // Batasi resolusi tinggi maksimal
    );

    if (image == null) return; // Batal ambil foto

    setState(() => isLoading = true);

    try {
      final String orderId = widget.tugas['id'].toString();
      final url = Uri.parse('$apiUrl/pesanan/$orderId/bayar-cod');

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('bukti_cod', image.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            currentStatus = 'Selesai';
            isLoading = false;
          });
          _stopTracking(); // Hentikan tracking
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Berhasil konfirmasi COD dan Selesai"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 422) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Foto terlalu besar (Max 1MB). Coba foto ulang."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw Exception("Gagal: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal upload foto bukti. Coba lagi."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double lat =
        double.tryParse(widget.tugas['latitude'].toString()) ?? -7.7956;
    double lng =
        double.tryParse(widget.tugas['longitude'].toString()) ?? 110.3695;
    LatLng lokasiPelanggan = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text("Navigasi ${widget.tugas['id_pesanan'] ?? ''}"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
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
                  const Text(
                    "Alamat Pelanggan",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    widget.tugas['alamat'] ?? '-',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Waktu Jemput: ${widget.tugas['tanggal_jemput']} | ${widget.tugas['waktu_jemput']}",
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(child: Icon(Icons.person)),
                          const SizedBox(width: 10),
                          Text(
                            widget.tugas['nama_pelanggan'] ?? 'Pelanggan',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.green),
                            onPressed: () {},
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
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(currentStatus),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              if (currentStatus == "Menunggu Konfirmasi") {
                                updateStatus("Kurir Menuju Lokasi");
                              } else if (currentStatus ==
                                  "Menunggu Penjemputan") {
                                updateStatus("Kurir Menuju Lokasi");
                              } else if (currentStatus ==
                                  "Kurir Menuju Lokasi") {
                                updateStatus("Tiba di Lokasi");
                              } else if (currentStatus == "Tiba di Lokasi") {
                                updateStatus("Pakaian Sedang Dicuci");
                                Navigator.pop(context, true);
                              } else if (currentStatus ==
                                  "Pakaian Siap Diantar") {
                                updateStatus("Diantar");
                              } else if (currentStatus == "Diantar") {
                                _uploadBuktiDanSelesai();
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _getButtonText(currentStatus),
                              style: const TextStyle(
                                fontSize: 18,
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
        return "Terima & Mulai Jemput";
      case "Menunggu Penjemputan":
        return "Mulai Jalan ke Pelanggan";
      case "Kurir Menuju Lokasi":
        return "Tiba di Lokasi Jemput";
      case "Tiba di Lokasi":
        return "Serahkan ke Cuci";
      case "Pakaian Siap Diantar":
        return "Mulai Antar Pakaian";
      case "Diantar":
        return "Pesanan Selesai Diantar";
      default:
        return "Update Status";
    }
  }

  Color _getButtonColor(String status) {
    if (status == "Kurir Menuju Lokasi") return Colors.orange;
    if (status == "Tiba di Lokasi") return Colors.green;
    return Colors.blue;
  }
}


