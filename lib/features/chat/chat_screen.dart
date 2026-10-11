import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laundrypoint/core/services/auth_http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../../core/services/badge_service.dart';
import '../../../core/theme/app_colors.dart';

class _Pesan {
  final int id;
  final String pengirim; // Pelanggan | Kurir | Admin
  final String isi;
  final String? gambar;
  final String? gambarUrl;
  final bool isMe;
  final DateTime waktu;

  _Pesan({
    required this.id,
    required this.pengirim,
    required this.isi,
    this.gambar,
    this.gambarUrl,
    required this.isMe,
    required this.waktu,
  });

  String? get displayGambarUrl {
    if (gambarUrl != null && gambarUrl!.isNotEmpty) {
      if (gambarUrl!.contains('localhost') || gambarUrl!.contains('127.0.0.1')) {
        final uri = Uri.parse(gambarUrl!);
        return '$apiBaseUrl${uri.path.replaceFirst('/api', '')}';
      }
      return gambarUrl;
    }
    if (gambar != null && gambar!.isNotEmpty) {
      return '$apiBaseUrl/chat-foto/$gambar';
    }
    return null;
  }

  factory _Pesan.fromJson(Map<String, dynamic> j) => _Pesan(
        id: (j['id'] as num).toInt(),
        pengirim: (j['pengirim'] ?? '').toString(),
        isi: (j['isi_pesan'] ?? '').toString(),
        gambar: j['gambar']?.toString(),
        gambarUrl: j['gambar_url']?.toString(),
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
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      _snack('Gagal mengambil gambar: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Kirim Foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ambil foto langsung dengan kamera HP'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.purple),
                ),
                title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Pilih gambar dari album / galeri HP'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kirim() async {
    final isi = _controller.text.trim();
    final imageFile = _selectedImage;

    if ((isi.isEmpty && imageFile == null) || _sending || _orderNumericId == null) {
      return;
    }

    setState(() => _sending = true);
    try {
      http.Response res;

      if (imageFile != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiBaseUrl/chat/kirim'),
        );
        request.fields['id_pesanan'] = _orderNumericId.toString();
        if (isi.isNotEmpty) {
          request.fields['isi_pesan'] = isi;
        }
        request.files.add(
          await http.MultipartFile.fromPath('gambar', imageFile.path),
        );

        final streamed = await request.send();
        res = await http.Response.fromStream(streamed);
      } else {
        res = await http.post(
          Uri.parse('$apiBaseUrl/chat/kirim'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_pesanan': _orderNumericId, 'isi_pesan': isi}),
        );
      }

      if (!mounted) return;

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body)['data'];
        final m = _Pesan.fromJson(Map<String, dynamic>.from(data));
        _controller.clear();
        setState(() {
          _selectedImage = null;
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

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  headers: const {'ngrok-skip-browser-warning': '69420'},
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
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
          if (_selectedImage != null) _buildImagePreview(),
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
              'Belum ada pesan.\nKirim pesan atau foto untuk memulai obrolan!',
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
    final hasPhoto = m.displayGambarUrl != null;
    final showText = m.isi.isNotEmpty && m.isi != '[Foto]';

    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  m.pengirim,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _warnaPengirim(m.pengirim),
                  ),
                ),
              ),
            if (hasPhoto) ...[
              GestureDetector(
                onTap: () => _showFullImage(m.displayGambarUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      minHeight: 120,
                    ),
                    width: double.infinity,
                    color: Colors.black.withOpacity(0.06),
                    child: Image.network(
                      m.displayGambarUrl!,
                      headers: const {'ngrok-skip-browser-warning': '69420'},
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 140,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: m.isMe ? Colors.white : AppColors.primary,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        alignment: Alignment.center,
                        color: Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey, size: 36),
                            SizedBox(height: 4),
                            Text(
                              'Gagal memuat foto',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showText) const SizedBox(height: 6),
            ],
            if (showText)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  m.isi,
                  style: TextStyle(
                    color: m.isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Text(
                  _jam(m.waktu),
                  style: TextStyle(
                    fontSize: 10,
                    color: m.isMe ? Colors.white70 : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _selectedImage!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Foto siap dikirim',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Bisa ketik pesan/keterangan sebelum kirim',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => setState(() => _selectedImage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.primary, size: 26),
              tooltip: 'Kirim Gambar',
              onPressed: _sending ? null : _showImagePickerModal,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary, size: 24),
              tooltip: 'Ambil Foto',
              onPressed: _sending ? null : () => _pickImage(ImageSource.camera),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _selectedImage != null
                      ? 'Keterangan foto (opsional)...'
                      : 'Ketik pesan Anda...',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
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