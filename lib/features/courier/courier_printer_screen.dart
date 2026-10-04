import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';

class CourierPrinterScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const CourierPrinterScreen({super.key, required this.orderData});

  @override
  State<CourierPrinterScreen> createState() => _CourierPrinterScreenState();
}

class _CourierPrinterScreenState extends State<CourierPrinterScreen> {
  String _info = "Mencari Perangkat...";
  String _msj = "";
  bool connected = false;
  List<BluetoothInfo> items = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    try {
      final List<BluetoothInfo> listResult = await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        items = listResult;
        _info = listResult.isEmpty 
          ? "Tidak ada perangkat Bluetooth terpasang" 
          : "Pilih Printer Bluetooth";
      });
    } catch (e) {
      setState(() {
        _info = "Error: $e";
      });
    }
  }

  Future<void> connect(String mac) async {
    setState(() {
      _info = "Menghubungkan...";
    });
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      setState(() {
        connected = result;
        if (connected) {
          _info = "Berhasil terhubung ke Printer!";
        } else {
          _info = "Gagal terhubung.";
        }
      });
    } catch (e) {
      setState(() {
        _info = "Gagal terhubung: $e";
      });
    }
  }

  Future<void> printTest() async {
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer belum terhubung!')),
      );
      return;
    }

    try {
      bool status = await PrintBluetoothThermal.connectionStatus;
      if (status) {
        List<int> ticket = await getReceiptData();
        final result = await PrintBluetoothThermal.writeBytes(ticket);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil mencetak: $result')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer terputus')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing: $e')),
      );
    }
  }

  Future<List<int>> getReceiptData() async {
    List<int> bytes = [];
    
    // Receipt Header
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 2, text: "PINT POINT LAUNDRY\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Tanda Terima & Bukti COD\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "================================\n"),
    );
    
    // Order Info
    String orderId = widget.orderData['id_pesanan']?.toString() ?? '-';
    String customer = widget.orderData['nama_pelanggan'] ?? 'Pelanggan';
    String service = widget.orderData['layanan'] ?? '-';
    String date = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Tanggal : $date\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Pesanan : $orderId\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Nama    : $customer\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Layanan : $service\n"),
    );
    
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "================================\n"),
    );
    
    // Price Info
    int price = int.tryParse(widget.orderData['total_harga']?.toString() ?? '0') ?? 0;
    String formattedPrice = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(price);
    
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 2, text: "TOTAL : $formattedPrice\n"),
    );
    
    String paymentMethod = widget.orderData['payment_method']?.toString().toUpperCase() ?? 'COD';
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "METODE: $paymentMethod\n"),
    );
    
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "================================\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "Terima kasih telah menggunakan\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "layanan Pint Point Laundry!\n"),
    );
    bytes += await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(size: 1, text: "\n\n\n"), // feed paper
    );
    
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cetak Struk COD"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Status: $_info",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text("Tidak ada perangkat yang dipasangkan (paired). Pastikan Bluetooth menyala dan printer sudah di-pairing."))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(items[index].name),
                            subtitle: Text(items[index].macAdress),
                            onTap: () {
                              connect(items[index].macAdress);
                            },
                          ),
                        );
                      },
                    ),
            ),
            if (connected)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text("Cetak Struk Sekarang", style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: printTest,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
