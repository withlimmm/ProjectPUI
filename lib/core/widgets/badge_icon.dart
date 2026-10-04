import 'package:flutter/material.dart';

/// Ikon dengan lencana (badge) merah berisi jumlah belum dibaca.
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final double size;

  const BadgeIcon({
    super.key,
    required this.icon,
    this.count = 0,
    this.color = Colors.white,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: size),
        if (count > 0)
          Positioned(
            right: -6,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Format waktu relatif singkat: "Baru saja", "5 menit lalu", "Kemarin", dst.
String formatWaktuRelatif(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final diff = now.difference(t);

  String two(int n) => n.toString().padLeft(2, '0');

  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return '${two(t.hour)}:${two(t.minute)}';
  }
  final kemarin = now.subtract(const Duration(days: 1));
  if (t.year == kemarin.year && t.month == kemarin.month && t.day == kemarin.day) {
    return 'Kemarin';
  }
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}
