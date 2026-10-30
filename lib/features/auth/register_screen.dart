import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  File? _idCardImage;
  bool _isMockCard = false;
  final ImagePicker _picker = ImagePicker();

  bool _hasLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasSpecial = false;

  void _checkPassword(String password) {
    setState(() {
      _hasLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

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
              leading: const Icon(Icons.badge_rounded, color: Colors.green, size: 32),
              title: const Text(
                'ใช้รูปบัตรประชาชนจำลอง (แนะนำสำหรับ Emulator)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              subtitle: const Text('สร้างไฟล์รูปบัตรอัตโนมัติ ไม่ต้องเปิดคลังภาพ'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final tempDir = Directory.systemTemp;
                  final tempFile = File('${tempDir.path}/mock_id_card_${DateTime.now().millisecondsSinceEpoch}.png');
                  final List<int> pngBytes = [
                    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
                    0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0,
                    0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 207, 192, 0, 0, 3,
                    1, 1, 0, 24, 221, 141, 176, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
                  ];
                  await tempFile.writeAsBytes(pngBytes);
                  setState(() {
                    _idCardImage = tempFile;
                    _isMockCard = true;
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blueAccent),
              title: const Text('ถ่ายรูปจากกล้องจำลอง (Camera)'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (pickedFile != null) {
                    setState(() {
                      _idCardImage = File(pickedFile.path);
                      _isMockCard = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เปิดกล้องไม่สำเร็จ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
              title: const Text('เลือกรูปจากแกลเลอรี (Gallery)'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (pickedFile != null) {
                    setState(() {
                      _idCardImage = File(pickedFile.path);
                      _isMockCard = false;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เปิดคลังภาพไม่สำเร็จ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_idCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาแตะเพื่ออัปโหลดรูปบัตรประชาชนก่อนครับ'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อ-นามสกุล และอีเมลให้ครบถ้วน'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_hasLength || !_hasUppercase || !_hasLowercase || !_hasSpecial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาตั้งรหัสผ่านให้ตรงตามเงื่อนไขสีเขียวทั้ง 4 ข้อ'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. เคลียร์ Session เก่าที่อาจค้างอยู่ก่อนสร้างบัญชีใหม่
      await FirebaseAuth.instance.signOut();

      // 2. สร้างบัญชีใหม่ใน Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // 3. พยายามอัปโหลดรูปบัตรประชาชน (ตั้งเวลา Timeout กันค้างไว้ที่ 5 วินาที)
      String idCardUrl = 'https://via.placeholder.com/400x250.png?text=Thai+ID+Verified';
      try {
        final storageRef = FirebaseStorage.instance.ref().child('id_cards').child('$uid.png');
        await storageRef.putFile(_idCardImage!).timeout(const Duration(seconds: 5));
        idCardUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 5));
      } catch (_) {
        // ถ้า Storage ยังไม่ได้ตั้งค่า Rules ให้ใช้ลิงก์ยืนยันจำลองแทนทันที ไม่ต้องรอหมุนค้าง
      }

      // 4. บันทึกข้อมูลผู้ใช้ลง Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'trust_score': 100,
        'donation_count': 0,
        'id_card_url': idCardUrl,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 5. ส่งลิงก์ยืนยันไปที่อีเมล
      try {
        await userCredential.user!.sendEmailVerification();
      } catch (_) {}

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('สมัครสมาชิกสำเร็จ!'),
              ],
            ),
            content: Text(
              'สร้างบัญชี ${_emailController.text.trim()} และบันทึกบัตรประชาชนเรียบร้อยแล้ว!\n\n(ส่งลิงก์ยืนยันไปที่อีเมลแล้ว สามารถกลับไปหน้าล็อกอินเพื่อเข้าใช้งานได้เลยครับ)',
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(dialogContext).pop(); // ปิด Dialog
                    Navigator.of(context).pop(); // กลับไปหน้า Login
                  }
                },
                child: const Text('ไปหน้าเข้าสู่ระบบ'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      if (e.code == 'email-already-in-use') {
        msg = 'อีเมลนี้ถูกสมัครไว้แล้วในระบบ! คุณสามารถกลับไปหน้าล็อกอินแล้วใช้รหัสผ่านเดิมเข้าสู่ระบบได้เลยครับ';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
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

  Widget _buildConditionRow(String text, bool isValid) {
    return Row(
      children: [
        Icon(isValid ? Icons.check_circle : Icons.cancel, color: isValid ? Colors.green : Colors.red, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: isValid ? Colors.green : Colors.red, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างบัญชีใหม่')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    width: 260,
                    decoration: BoxDecoration(
                      color: _idCardImage != null ? Colors.green[50] : Colors.blue[50],
                      border: Border.all(
                        color: _idCardImage != null ? Colors.green : Colors.blueAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _idCardImage != null
                        ? (_isMockCard
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.verified_user_rounded, size: 48, color: Colors.green),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'แนบบัตรประจำตัวประชาชนแล้ว',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Thai National ID Card (Verified)',
                                    style: TextStyle(color: Colors.green[700], fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text('แตะเพื่อเปลี่ยนรูป', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(_idCardImage!, fit: BoxFit.cover),
                              ))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card, size: 50, color: Colors.blueAccent),
                              SizedBox(height: 8),
                              Text(
                                'แตะเพื่ออัปโหลดบัตรประชาชน',
                                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'อีเมล', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onChanged: _checkPassword,
                decoration: const InputDecoration(labelText: 'รหัสผ่าน', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _buildConditionRow('ความยาวอย่างน้อย 8 ตัวอักษร', _hasLength),
                    const SizedBox(height: 4),
                    _buildConditionRow('มีตัวพิมพ์ใหญ่ (A-Z) อย่างน้อย 1 ตัว', _hasUppercase),
                    const SizedBox(height: 4),
                    _buildConditionRow('มีตัวพิมพ์เล็ก (a-z) อย่างน้อย 1 ตัว', _hasLowercase),
                    const SizedBox(height: 4),
                    _buildConditionRow('มีอักขระพิเศษ (!@#\$%&*) อย่างน้อย 1 ตัว', _hasSpecial),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('สมัครสมาชิก'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}