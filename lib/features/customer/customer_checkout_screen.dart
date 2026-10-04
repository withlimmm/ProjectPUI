import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import 'dart:convert';

// --- IMPORT PAKET PETA GRATIS (FLUTTER MAP) ---
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';
import 'customer_review_order_screen.dart';

class CustomerCheckoutScreen extends StatefulWidget {
  final String layanan;
  final double berat;
  final int totalHarga;
  final String catatan;
  final int ongkir; // Diterima dari screen sebelumnya
  final String packageId;

  const CustomerCheckoutScreen({
    super.key,
    required this.layanan,
    required this.berat,
    required this.totalHarga,
    required this.catatan,
    this.ongkir = 10000, // Default Rp 10.000
    this.packageId = '',
  });

  @override
  State<CustomerCheckoutScreen> createState() => _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState extends State<CustomerCheckoutScreen> {
  // Radius config
  double _radiusKm = 15.0;
  double _tokoLat = -7.751452341173487;
  double _tokoLng = 110.35193545872235;
  String _jamBuka = "08:00";
  String _jamTutup = "20:00";
  bool _radiusFetched = false;
  bool isGettingLocation = true;
  bool isLocaleReady = false;
  bool isLoading = false;

  String promoCode = "";
  double diskonKupon = 0;

  // Variabel Peta Flutter Map
  late final MapController _mapController;
  LatLng _centerMap = const LatLng(
    -7.3274,
    108.2207,
  ); // Titik Awal: Tasikmalaya
  String alamatLengkap = "Mencari lokasi...";

  // Controller untuk fitur Edit Alamat
  final TextEditingController _detailAlamatController = TextEditingController();

  // Variabel Jadwal
  late DateTime selectedDate;
  String selectedTime = "08:00";
  List<DateTime> listHari = [];
  List<String> listJam = [
    "08:00",
    "09:00",
    "10:00",
    "11:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
    "17:00",
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    selectedDate = DateTime.now();
    _generateHari();
    _fetchDeliveryConfig();

    // Inisialisasi Bahasa Indonesia untuk format tanggal
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() {
          isLocaleReady = true;
        });
      }
    });

    // Otomatis cari lokasi saat halaman dibuka
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _detailAlamatController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- FETCH DELIVERY CONFIG (radius) ---
  Future<void> _fetchDeliveryConfig() async {
    if (_radiusFetched) return;
    try {
      final res = await http
          .get(Uri.parse('$apiBaseUrl/settings/delivery'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _radiusKm = (data['radius_km'] as num).toDouble();
            _tokoLat = (data['toko_lat'] as num).toDouble();
            _tokoLng = (data['toko_lng'] as num).toDouble();
            _jamBuka = data['jam_buka'] ?? "08:00";
            _jamTutup = data['jam_tutup'] ?? "20:00";
            _radiusFetched = true;
          });
        }
      }
    } catch (_) {}
  }

  // --- HITUNG JARAK (HAVERSINE) ---
  double _hitungJarak(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (3.14159265358979 / 180);
    final dLng = (lng2 - lng1) * (3.14159265358979 / 180);
    final a = (dLat / 2) * (dLat / 2) +
        (dLng / 2) * (dLng / 2);
    return r * 2 * (a < 1 ? a : 1);
  }

  // --- FITUR: TAMPILKAN POPUP KALENDER ---
  Future<void> _pilihTanggalDariKalender() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(), // Tidak bisa pilih hari kemarin
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ), // Maksimal 30 hari ke depan
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> terapkanPromo() async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/promo/check'), // Gunakan URL API Anda
      body: {'kode_promo': promoCode}
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        // We will try 'diskon' first, fallback to 'nilai_diskon' in 'data'
        final diskonVal = data['diskon'] ?? (data['data'] != null ? data['data']['nilai_diskon'] : 0);
        diskonKupon = double.parse(diskonVal.toString());
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kupon berhasil digunakan!")));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kupon tidak valid.")));
      }
    }
  }

  // --- FITUR: DIALOG EDIT ALAMAT MANUAL ---
  void _tampilkanDialogEditAlamat() {
    _detailAlamatController.text = alamatLengkap;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Detail Alamat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: _detailAlamatController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Tambahkan patokan, nomor kamar/rumah, dll.',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  alamatLengkap = _detailAlamatController.text;
                });
                Navigator.pop(context); // Tutup dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _generateHari() {
    listHari.clear();
    for (int i = 0; i < 30; i++) {
      listHari.add(DateTime.now().add(Duration(days: i)));
    }
  }

  // --- FITUR PETA GRATIS: DAPATKAN GPS TERKINI ---
  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'GPS belum dinyalakan.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        LatLng newPos = LatLng(position.latitude, position.longitude);
        setState(() {
          _centerMap = newPos;
        });

        // Pindahkan kamera ke titik GPS terkini
        _mapController.move(newPos, 16.0);
        await _getAddressFromLatLng(newPos.latitude, newPos.longitude);
      }
    } catch (e) {
      debugPrint("Gagal dapat GPS: $e");
      if (mounted) setState(() => isGettingLocation = false);
    }
  }

  // --- FITUR PETA GRATIS: TRANSLATE TITIK KE ALAMAT TEKS (NOMINATIM) ---
  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    setState(() => isGettingLocation = true);
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'PintPointLaundryApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            alamatLengkap = data['display_name'] ?? "Alamat tidak ditemukan";
            _detailAlamatController.text =
                alamatLengkap; // Update field edit juga
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => alamatLengkap =
              "Gagal memuat nama jalan. Coba geser peta sedikit.",
        );
      }
    } finally {
      if (mounted) setState(() => isGettingLocation = false);
    }
  }

  void _konfirmasiPesanan() {
    // [TAMBAHKAN KODE INI]
    final String currentTime = DateFormat('HH:mm').format(DateTime.now());
    if (currentTime.compareTo(_jamBuka) < 0 || currentTime.compareTo(_jamTutup) > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Pint Point Sedang Tutup"),
          content: Text("Maaf, kami hanya beroperasi jam $_jamBuka - $_jamTutup WIB."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Mengerti"),
            ),
          ],
        ),
      );
      return; // Stop di sini, API Create Order TIDAK AKAN dijalankan
    }
    // [BATAS TAMBAHAN KODE]
    // Cek radius sebelum lanjut (soft warning, tidak block)
    final jarak = _hitungJarak(
        _centerMap.latitude, _centerMap.longitude, _tokoLat, _tokoLng);
    if (jarak > _radiusKm) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Di Luar Area Layanan'),
          ]),
          content: Text(
            'Lokasi Anda berada sekitar ${jarak.toStringAsFixed(1)} km dari toko, '
            'melebihi radius layanan kami (${_radiusKm.toStringAsFixed(0)} km).\n\n'
            'Area layanan: Mlati, Sinduadi, Sleman dan sekitarnya.\n\n'
            'Pesanan tetap bisa dikirim, namun mungkin ditolak oleh sistem.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batalkan')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange),
              onPressed: () {
                Navigator.pop(ctx);
                _lanjutKeReview();
              },
              child: const Text('Tetap Lanjutkan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _lanjutKeReview();
    }
  }

  void _lanjutKeReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerReviewOrderScreen(
          layanan: widget.layanan,
          berat: widget.berat,
          totalHarga: (widget.totalHarga - diskonKupon).toInt(),
          catatan: widget.catatan,
          alamat: alamatLengkap,
          latitude: _centerMap.latitude.toString(),
          longitude: _centerMap.longitude.toString(),
          tanggal: selectedDate,
          waktu: selectedTime,
          ongkir: widget.ongkir,
          packageId: widget.packageId,
        ),
      ),
    );
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
              'Langkah 2 dari 2',
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
                Expanded(child: Container(height: 3, color: AppColors.primary)),
                const SizedBox(width: 5),
                Expanded(child: Container(height: 3, color: AppColors.primary)),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Masukkan Kupon Diskon",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => promoCode = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: terapkanPromo,
                      child: const Text("Terapkan"),
                    )
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimasi Total',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(widget.totalHarga - diskonKupon)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF67C9EC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: isLoading ? null : _konfirmasiPesanan,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Konfirmasi Pesanan',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- AREA PETA GRATIS FLUTTER MAP ---
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _centerMap,
                      initialZoom: 15.0,
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() => _centerMap = position.center);
                        }
                      },
                      onMapEvent: (event) {
                        if (event is MapEventMoveEnd) {
                          _getAddressFromLatLng(
                            _centerMap.latitude,
                            _centerMap.longitude,
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

                  // Pin Statis Ala Gojek di tengah
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.redAccent,
                        size: 50,
                      ),
                      SizedBox(
                        height: 50,
                      ), // Spasi agar ujung bawah pin pas di tengah titik
                    ],
                  ),

                  // Tombol Deteksi Lokasi
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: _getCurrentLocation,
                      child: const Icon(Icons.my_location, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alamat Lengkap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _tampilkanDialogEditAlamat,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.edit,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Edit Detail',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: isGettingLocation
                              ? const Text(
                                  "Sedang mendeteksi alamat...",
                                  style: TextStyle(color: Colors.grey),
                                )
                              : Text(
                                  alamatLengkap,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  GestureDetector(
                    onTap: _pilihTanggalDariKalender,
                    child: const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tanggal Penjemputan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 80,
                    child: isLocaleReady
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: listHari.length,
                            itemBuilder: (context, index) {
                              DateTime tgl = listHari[index];
                              bool isSelected =
                                  selectedDate.year == tgl.year &&
                                  selectedDate.month == tgl.month &&
                                  selectedDate.day == tgl.day;

                              return GestureDetector(
                                onTap: () => setState(() => selectedDate = tgl),
                                child: Container(
                                  width: 65,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        (DateTime.now().day == tgl.day &&
                                                DateTime.now().month ==
                                                    tgl.month)
                                            ? "Hari ini"
                                            : DateFormat(
                                                'E',
                                                'id_ID',
                                              ).format(tgl),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        tgl.day.toString(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM', 'id_ID').format(tgl),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                  const SizedBox(height: 25),
                  const Row(
                    children: [
                      Icon(Icons.access_time, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Jam Penjemputan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: listJam.map((jam) {
                      bool isSelected = selectedTime == jam;
                      return GestureDetector(
                        onTap: () => setState(() => selectedTime = jam),
                        child: Container(
                          width: (MediaQuery.of(context).size.width - 60) / 3,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            jam,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
