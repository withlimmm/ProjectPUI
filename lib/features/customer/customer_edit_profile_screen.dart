import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_config.dart';

class CustomerEditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String? currentPhotoUrl;

  const CustomerEditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentPhone,
    this.currentPhotoUrl,
  });

  @override
  State<CustomerEditProfileScreen> createState() =>
      _CustomerEditProfileScreenState();
}

class _CustomerEditProfileScreenState extends State<CustomerEditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool isLoading = false;
  String userId = "";

  String get apiUrl => apiBaseUrl;
  String get storageUrl => storageBaseUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id') ?? "";
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- FUNGSI GANTI FOTO PROFIL (Multipart POST) ---
  Future<void> _pickAndUploadPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null && userId.isNotEmpty) {
      setState(() => isLoading = true);
      try {
        // Alamat API upload foto yang sudah kita buat sebelumnya
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiUrl/profil/update/$userId'),
        );
        var bytes = await pickedFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'foto_profil',
            bytes,
            filename: pickedFile.name,
          ),
        );

        var streamedResponse = await request.send();
        if (streamedResponse.statusCode == 200) {
          _showPesan("Foto berhasil diperbarui!", isSukses: true);

          // ✅ BARU: Reload profil data setelah upload
          await Future.delayed(const Duration(milliseconds: 500));
          await _reloadProfileData();
        } else {
          _showPesan("Gagal mengupload foto.");
        }
      } catch (e) {
        _showPesan("Kesalahan jaringan saat upload foto.");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  // ✅ BARU: Fungsi reload profil data
  Future<void> _reloadProfileData() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/profil/$userId'));
      if (response.statusCode == 200) {
        // Clear image cache untuk foto lama
        imageCache.clearLiveImages();
        imageCache.clear();
        imageCache.clearLiveImages();

        // Update ke parent screen dengan data terbaru
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("Error reload profil: $e");
    }
  }

  // --- FUNGSI SIMPAN PERUBAHAN TEKS (PUT Request) ---
  Future<void> _saveProfileChanges() async {
    if (_nameController.text.isEmpty) {
      _showPesan("Nama tidak boleh kosong!");
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.put(
        Uri.parse('$apiUrl/profil/update-text/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text,
          'no_hp': _phoneController.text,
        }),
      );

      if (response.statusCode == 200) {
        // Update Nama di memori lokal (SharedPreferences)
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text);

        _showPesan("Profil berhasil diperbarui!", isSukses: true);

        // ✅ Return true ke parent untuk trigger reload
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showPesan("Gagal menyimpan perubahan teks.");
      }
    } catch (e) {
      _showPesan("Kesalahan jaringan saat menyimpan.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showPesan(String pesan, {bool isSukses = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: isSukses ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Profil",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(15),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfileChanges,
              child: const Text(
                "Simpan",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // BAGIAN FOTO PROFIL (Bisa diklik untuk ganti)
            GestureDetector(
              onTap: _pickAndUploadPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      image:
                          (widget.currentPhotoUrl != null &&
                              widget.currentPhotoUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(
                                '$storageUrl/${widget.currentPhotoUrl}',
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        (widget.currentPhotoUrl == null ||
                            widget.currentPhotoUrl!.isEmpty)
                        ? Center(
                            child: Text(
                              widget.currentName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Text(
              "Ketuk untuk ganti foto",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),

            const SizedBox(height: 40),

            // FORM INPUT NAMA
            _buildEditField(
              controller: _nameController,
              label: "Nama Lengkap",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            // FORM INPUT NO HP
            _buildEditField(
              controller: _phoneController,
              label: "No. WhatsApp",
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 40),
            Text(
              'ID Pengguna: $userId',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textDark, fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ],
    );
  }
}
