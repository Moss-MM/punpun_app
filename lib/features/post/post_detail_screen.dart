import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const PostDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMyPost = data['owner_uid'] == currentUserId;
    final imageUrl = data['image_url'] as String?;

    Widget imageWidget = Container(
      height: 220,
      width: double.infinity,
      color: Colors.blue[50],
      child: Icon(Icons.image_outlined, size: 64, color: Colors.blue[200]),
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('data:image')) {
        imageWidget = Image.memory(
          base64Decode(imageUrl.split(',').last),
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } else {
        imageWidget = Image.network(
          imageUrl,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(data['title'] ?? 'รายละเอียดสิ่งของ')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            imageWidget,
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          data['post_type'] ?? 'ให้',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(data['category'] ?? 'ทั่วไป'),
                        backgroundColor: Colors.grey[200],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['title'] ?? 'ไม่มีชื่อสิ่งของ',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'สภาพสิ่งของ: ${data['condition'] ?? '-'}',
                    style: const TextStyle(fontSize: 15, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                  if (data['brand_size'] != null && data['brand_size'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ขนาด / ยี่ห้อ: ${data['brand_size']}',
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                    ),
                  ],
                  const Divider(height: 32),
                  const Text('รายละเอียดเพิ่มเติม:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    data['description'] ?? 'ไม่มีรายละเอียด',
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  if (!isMyPost)
                    ElevatedButton.icon(
                      onPressed: () async {
                        String ownerName = 'ผู้โพสต์';
                        try {
                          final doc = await FirebaseFirestore.instance.collection('users').doc(data['owner_uid']).get();
                          if (doc.exists) ownerName = doc.data()?['name'] ?? 'ผู้โพสต์';
                        } catch (_) {}

                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                receiverId: data['owner_uid'],
                                receiverName: ownerName,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('ทักแชทติดต่อขอรับ / แลกเปลี่ยน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}