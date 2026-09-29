import 'package:flutter/material.dart';

// Import ketiga file tab yang akan kita buat
import 'courier_home_tab.dart';
import 'courier_history_tab.dart';
import 'courier_account_tab.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  int _selectedIndex = 0;

  // Daftar halaman yang akan dipanggil saat menu bawah diklik
  final List<Widget> _pages = [
    const CourierHomeTab(), // Index 0
    const CourierHistoryTab(), // Index 1
    const CourierAccountTab(), // Index 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], // Menampilkan halaman sesuai index
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF00A2E9),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.motorcycle), label: 'Tugas'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
