import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _brandSizeController = TextEditingController();

  String _postType = 'ให้';
  String _category = 'เสื้อผ้า/รองเท้า/แฟชั่น';
  String _condition = 'ของใหม่ (100%)';
  int _expireDays = 7;

  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final List<String> _postTypes = ['ให้', 'ขอรับ', 'แลก'];
  final List<String> _categories = [
    'เสื้อผ้า/รองเท้า/แฟชั่น',
    'หน้ากากอนามัย/เจลแอลกอฮอล์/การแพทย์',
    'หนังสือ/การเรียน',
    'อุปกรณ์อิเล็กทรอนิกส์',
    'ของใช้ในบ้าน/หอพัก',
    'อุปกรณ์กีฬา',
    'อื่นๆ'
  ];
  final List<String> _conditions = [
    'ของใหม่ (100%)',
    'มือสอง สภาพนางฟ้า (95%+)',
    'มือสอง สภาพดี (80-90%)',
    'มีตำหนิแต่ใช้งานได้ปกติ',
  ];
  final List<int> _expireOptions = [1, 3, 5, 7];

  Future<void> _pickImage() async {
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
              title: const Text('ถ่ายรูปสิ่งของ (Camera)'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 60,
                );
                if (picked != null) {
                  setState(() => _selectedImage = File(picked.path));
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
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 60,
                );
                if (picked != null) {
                  setState(() => _selectedImage = File(picked.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    FocusScope.of(context).unfocus();
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อสิ่งของและรายละเอียดให้ครบถ้วน'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? imageDataUrl;

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final base64String = base64Encode(bytes);
        imageDataUrl = 'data:image/jpeg;base64,$base64String';
      }

      final expiresAt = DateTime.now().add(Duration(days: _expireDays));
      final titleText = _titleController.text.trim();

      await FirebaseFirestore.instance.collection('posts').add({
        'owner_uid': user.uid,
        'title': titleText,
        'description': _descController.text.trim(),
        'post_type': _postType,
        'category': _category,
        'condition': _condition,
        'brand_size': _brandSizeController.text.trim(),
        'image_url': imageDataUrl,
        'expire_days': _expireDays,
        'expires_at': Timestamp.fromDate(expiresAt),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (_postType == 'ให้') {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'donation_count': FieldValue.increment(1),
          'trust_score': FieldValue.increment(5),
        }, SetOptions(merge: true));
      }

      // แจ้งเตือนสมาชิกเมื่อมีโพสต์ใหม่ที่ตรงความต้องการเข้ามาในระบบ (โจทย์ข้อ a.vi)
      final usersSnap = await FirebaseFirestore.instance.collection('users').limit(10).get();
      for (var doc in usersSnap.docs) {
        if (doc.id != user.uid) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiver_id': doc.id,
            'sender_id': user.uid,
            'sender_name': user.email?.split('@').first ?? 'สมาชิก',
            'title': 'โพสต์ใหม่หมวด $_category ($_postType) 🔔',
            'body': '$titleText • ${_brandSizeController.text.trim()}',
            'type': 'match',
            'is_read': false,
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สร้างโพสต์สำเร็จเรียบร้อย!'), backgroundColor: Colors.green),
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
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างโพสต์แบ่งปัน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent, width: 1.5),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 48, color: Colors.blueAccent),
                          SizedBox(height: 8),
                          Text('แตะเพื่อถ่ายรูป หรือเลือกรูปสิ่งของ', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: _postType,
              decoration: const InputDecoration(labelText: 'ประเภทโพสต์ (ให้ / ขอรับ / แลก)', border: OutlineInputBorder()),
              items: _postTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _postType = val!),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'หมวดหมู่สินค้า', border: OutlineInputBorder()),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _category = val!),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'ชื่อสิ่งของ (เช่น รองเท้า Nike 1 คู่, เจลแอลกอฮอล์)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'สภาพสิ่งของ', border: OutlineInputBorder()),
              items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _condition = val!),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _brandSizeController,
              decoration: const InputDecoration(
                labelText: 'ขนาด / ยี่ห้อ (เช่น Nike ไซส์ 42, ขนาด 500ml)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<int>(
              initialValue: _expireDays,
              decoration: const InputDecoration(
                labelText: 'ระยะเวลาหมดอายุของโพสต์ (ไม่เกิน 7 วัน)',
                prefixIcon: Icon(Icons.timer_outlined, color: Colors.redAccent),
                border: OutlineInputBorder(),
              ),
              items: _expireOptions.map((d) => DropdownMenuItem(value: d, child: Text('$d วัน'))).toList(),
              onChanged: (val) => setState(() => _expireDays = val!),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'รายละเอียดเพิ่มเติม / สิ่งของที่ต้องการแลก',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _submitPost,
                    icon: const Icon(Icons.check),
                    label: const Text('โพสต์เลย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}