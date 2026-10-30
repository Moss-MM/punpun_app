import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditPostScreen extends StatefulWidget {
  final String docId;
  final String currentTitle;
  final String currentDesc;

  const EditPostScreen({
    super.key, 
    required this.docId, 
    required this.currentTitle, 
    required this.currentDesc,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ดึงข้อมูลเดิมมาใส่ในช่องพิมพ์รอไว้เลย
    _titleController = TextEditingController(text: widget.currentTitle);
    _descController = TextEditingController(text: widget.currentDesc);
  }

  Future<void> _updatePost() async {
    if (_titleController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });
    try {
      // ใช้คำสั่ง .update() เพื่อแก้ไขข้อมูลใน Firestore
      await FirebaseFirestore.instance.collection('posts').doc(widget.docId).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(), // บันทึกเวลาที่แก้ไข
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตข้อมูลสำเร็จ!'), backgroundColor: Colors.green),
        );
        // เด้งกลับไปหน้า Feed เลย (ถอยกลับ 2 หน้าจอ)
        Navigator.pop(context); 
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขสิ่งของ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'ชื่อสิ่งของ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 4, 
              decoration: const InputDecoration(labelText: 'รายละเอียด', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            _isLoading 
                ? const CircularProgressIndicator(color: Colors.red) 
                : ElevatedButton(
                    onPressed: _updatePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, // ใช้สีส้มเพื่อให้ต่างจากปุ่มโพสต์ใหม่
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}