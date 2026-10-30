import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentData;

  const EditProfileScreen({super.key, required this.currentData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  String? _avatarBase64;
  int _selectedBannerColor = 0xFF2196F3; // สีเริ่มต้น (Blue)
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final List<int> _bannerColors = [
    0xFF2196F3, // ฟ้า PunPun
    0xFF7E57C2, // ม่วงพาสเทล
    0xFF26A69A, // เขียวมรกต
    0xFFFF7043, // ส้มพีช
    0xFFEC407A, // ชมพูซากุระ
    0xFF37474F, // เทาดำสุดเท่
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name'] ?? '');
    _bioController = TextEditingController(text: widget.currentData['bio'] ?? '');
    _phoneController = TextEditingController(text: widget.currentData['phone'] ?? '');
    _avatarBase64 = widget.currentData['avatar_url'];
    if (widget.currentData['banner_color'] != null) {
      _selectedBannerColor = widget.currentData['banner_color'];
    }
  }

  Future<void> _pickAvatar() async {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blueAccent),
              title: const Text('ถ่ายรูปโปรไฟล์ (Camera)'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 400,
                  maxHeight: 400,
                  imageQuality: 65,
                );
                if (picked != null) {
                  final bytes = await File(picked.path).readAsBytes();
                  setState(() {
                    _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
              title: const Text('เลือกรูปจากแกลเลอรี (Gallery)'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 400,
                  maxHeight: 400,
                  imageQuality: 65,
                );
                if (picked != null) {
                  final bytes = await File(picked.path).readAsBytes();
                  setState(() {
                    _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อ-นามสกุล'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'phone': _phoneController.text.trim(),
          'avatar_url': _avatarBase64,
          'banner_color': _selectedBannerColor,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกการตกแต่งโปรไฟล์เรียบร้อย!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarProvider;
    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      if (_avatarBase64!.startsWith('data:image')) {
        avatarProvider = MemoryImage(base64Decode(_avatarBase64!.split(',').last));
      } else {
        avatarProvider = NetworkImage(_avatarBase64!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตกแต่งโปรไฟล์'),
        backgroundColor: Color(_selectedBannerColor),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ส่วนหัวพรีวิวปกและรูปโปรไฟล์
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color(_selectedBannerColor),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                ),
                Positioned(
                  bottom: -45,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue[100],
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
                                ? Text(
                                    _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(_selectedBannerColor),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            const Text('แตะที่รูปวงกลมเพื่อเปลี่ยนรูปโปรไฟล์', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('เลือกสีธีมหน้าปกโปรไฟล์:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _bannerColors.map((colorHex) {
                      final isSelected = _selectedBannerColor == colorHex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBannerColor = colorHex),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.black87 : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อที่แสดง (Display Name)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _bioController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'คำแนะนำตัว / สไตล์การแบ่งปัน (Bio)',
                      hintText: 'เช่น ชอบแบ่งปันหนังสือเรียนและเสื้อผ้ามือสองสภาพดีครับ 🌱',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'ช่องทางติดต่อเพิ่มเติม / Line ID / คณะ',
                      hintText: 'เช่น คณะวิศวกรรมศาสตร์ / Line: @punpun',
                      prefixIcon: Icon(Icons.contact_phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('บันทึกการเปลี่ยนแปลง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(_selectedBannerColor),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}