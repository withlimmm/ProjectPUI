import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;
import '../../../core/services/api_config.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/theme/app_colors.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _notifikasi = [];

  @override
  void initState() {
    super.initState();
    _loadNotifikasi();
  }

  Future<void> _loadNotifikasi() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/notifikasi'));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _notifikasi = json['data'] ?? [];
          _loading = false;
        });
        BadgeService.refresh(); // Update the badge
      } else {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat notifikasi (Status: ${res.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal terhubung ke server.';
      });
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    if (_notifikasi[index]['read_at'] != null) return;

    try {
      final res = await http.post(Uri.parse('$apiBaseUrl/notifikasi/$id/baca'));
      if (res.statusCode == 200) {
        setState(() {
          _notifikasi[index]['read_at'] = DateTime.now().toString();
        });
        BadgeService.refresh();
      }
    } catch (e) {
      debugPrint('Gagal menandai dibaca: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final res = await http.post(Uri.parse('$apiBaseUrl/notifikasi/baca-semua'));
      if (res.statusCode == 200) {
        setState(() {
          for (var notif in _notifikasi) {
            notif['read_at'] = DateTime.now().toString();
          }
        });
        BadgeService.refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi telah dibaca.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal menandai semua dibaca: $e');
    }
  }

  String _formatWaktu(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return DateFormat('dd MMM yyyy HH:mm').format(dt);
    } catch (e) {
      return isoTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tandai semua dibaca',
            onPressed: _notifikasi.isNotEmpty ? _markAllAsRead : null,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifikasi,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_notifikasi.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Belum ada notifikasi.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifikasi,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifikasi.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notif = _notifikasi[index];
          final bool isUnread = notif['read_at'] == null;

          return GestureDetector(
            onTap: () => _markAsRead(notif['id'].toString(), index),
            child: Container(
              decoration: BoxDecoration(
                color: isUnread ? Colors.blue.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isUnread
                    ? Border.all(color: AppColors.primary.withOpacity(0.3))
                    : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: isUnread ? AppColors.primary : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['data']['title'] ?? 'Notifikasi',
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                            color: isUnread ? Colors.black87 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif['data']['message'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isUnread ? Colors.black87 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatWaktu(notif['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isUnread)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
