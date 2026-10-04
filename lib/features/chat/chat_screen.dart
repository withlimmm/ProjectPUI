import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/theme/app_colors.dart';

class _Pesan {
  final int id;
  final String pengirim; // Pelanggan | Kurir | Admin
  final String isi;
  final bool isMe;
  final DateTime waktu;

  _Pesan({
    required this.id,
    required this.pengirim,
    required this.isi,
    required this.isMe,
    required this.waktu,
  });

  factory _Pesan.fromJson(Map<String, dynamic> j) => _Pesan(
    id: (j['id'] as num).toInt(),
    pengirim: (j['pengirim'] ?? '').toString(),
    isi: (j['isi_pesan'] ?? '').toString(),
    isMe: j['is_me'] == true,
    waktu: DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
  );
}

/// Chat per pesanan (Pelanggan <-> Kurir <-> Admin) lewat API Laravel.
/// [orderId] boleh berupa id angka ("7") atau kode pesanan ("PP-20261004-007").
class ChatScreen extends StatefulWidget {
  final String orderId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Pesan> _pesan = [];

  Timer? _timer;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _lastId = 0;

  late final int? _orderNumericId = _parseOrderId(widget.orderId);

  static int? _parseOrderId(String raw) {
    final last = raw.contains('-') ? raw.split('-').last : raw;
    return int.tryParse(last.trim());
  }

  String get _kode => widget.orderId.contains('-')
      ? widget.orderId
      : 'Pesanan #${widget.orderId}';

  @override
  void initState() {
    super.initState();
    if (_orderNumericId == null) {
      _loading = false;
      _error = 'ID pesanan tidak valid.';
      return;
    }
    _load(first: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    BadgeService.refresh();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    if (_orderNumericId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/chat/$_orderNumericId?after_id=$_lastId'),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final list = (json['data'] as List)
            .map((e) => _Pesan.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final adaBaru = list.isNotEmpty;
        setState(() {
          _loading = false;
          _error = null;
          _pesan.addAll(list.where((m) => m.id > _lastId));
          if (_pesan.isNotEmpty) {
            _lastId = _pesan.map((m) => m.id).reduce((a, b) => a > b ? a : b);
          }
        });
        if (adaBaru) _scrollToBottom(force: first);
      } else if (res.statusCode == 403 || res.statusCode == 404) {
        _timer?.cancel();
        String msg = 'Chat tidak dapat dibuka.';
        try {
          msg = jsonDecode(res.body)['message']?.toString() ?? msg;
        } catch (_) {}
        setState(() {
          _loading = false;
          _error = msg;
        });
      } else if (first) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat pesan (Status: ${res.statusCode})';
        });
      }
    } catch (e) {
      if (first && mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal terhubung ke server. Periksa koneksi internet Anda.';
        });
      }
    }
  }

  Future<void> _kirim() async {
    final isi = _controller.text.trim();
    if (isi.isEmpty || _sending || _orderNumericId == null) return;

    setState(() => _sending = true);
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/chat/kirim'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_pesanan': _orderNumericId, 'isi_pesan': isi}),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body)['data'];
        final m = _Pesan.fromJson(Map<String, dynamic>.from(data));
        _controller.clear();
        setState(() {
          if (!_pesan.any((p) => p.id == m.id)) _pesan.add(m);
          if (m.id > _lastId) _lastId = m.id;
        });
        _scrollToBottom(force: true);
      } else {
        String msg = 'Gagal mengirim pesan (Status: ${res.statusCode})';
        try {
          msg = jsonDecode(res.body)['message']?.toString() ?? msg;
        } catch (_) {}
        _snack(msg);
      }
    } catch (_) {
      _snack('Gagal terhubung ke server. Pesan belum terkirim.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 160;
      if (force || nearBottom) {
        _scroll.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _jam(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _labelHari(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'Hari ini';
    }
    final k = now.subtract(const Duration(days: 1));
    if (t.year == k.year && t.month == k.month && t.day == k.day) {
      return 'Kemarin';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  Color _warnaPengirim(String p) {
    switch (p) {
      case 'Kurir':
        return const Color(0xFFD97706);
      case 'Admin':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0891B2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                widget.receiverName.isNotEmpty
                    ? widget.receiverName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _kode,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_error == null || _pesan.isNotEmpty) _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null && _pesan.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              if (_orderNumericId != null)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load(first: true);
                    _timer?.cancel();
                    _timer = Timer.periodic(
                      const Duration(seconds: 3),
                      (_) => _load(),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
            ],
          ),
        ),
      );
    }

    if (_pesan.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Belum ada pesan.\nKirim pesan untuk memulai obrolan!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: _pesan.length,
      itemBuilder: (context, i) {
        final m = _pesan[i];
        final tampilHari =
            i == 0 ||
            _labelHari(_pesan[i - 1].waktu) != _labelHari(m.waktu);
        return Column(
          children: [
            if (tampilHari)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _labelHari(m.waktu),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            _bubble(m),
          ],
        );
      },
    );
  }

  Widget _bubble(_Pesan m) {
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: m.isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.isMe ? 16 : 4),
            bottomRight: Radius.circular(m.isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  m.pengirim,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _warnaPengirim(m.pengirim),
                  ),
                ),
              ),
            Text(
              m.isi,
              style: TextStyle(
                color: m.isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _jam(m.waktu),
                style: TextStyle(
                  fontSize: 10,
                  color: m.isMe ? Colors.white70 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Ketik pesan Anda...',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _kirim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
