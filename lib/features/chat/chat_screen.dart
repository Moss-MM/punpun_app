import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? chatRoomIdOverride;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.chatRoomIdOverride,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    try {
      if (avatarUrl.startsWith('data:image')) {
        return MemoryImage(base64Decode(avatarUrl.split(',').last));
      }
      return NetworkImage(avatarUrl);
    } catch (_) {
      return null;
    }
  }

  String getChatRoomId(String user1, String user2) {
    if (widget.chatRoomIdOverride != null && widget.chatRoomIdOverride!.isNotEmpty) {
      return widget.chatRoomIdOverride!;
    }
    final List<String> ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUserId.isEmpty) return;

    _messageController.clear();
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    try {
      String senderName = 'สมาชิกปันปัน';
      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (senderDoc.exists) {
        senderName = senderDoc.data()?['name'] ?? 'สมาชิกปันปัน';
      }

      await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
        'participants': [currentUserId, widget.receiverId],
        'last_message': text,
        'last_sender_id': currentUserId,
        'unread_by': widget.receiverId,
        'has_unread': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'sender_id': currentUserId,
        'receiver_id': widget.receiverId,
        'text': text,
        'created_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'receiver_id': widget.receiverId,
        'sender_id': currentUserId,
        'sender_name': senderName,
        'title': 'ข้อความใหม่จาก $senderName 💬',
        'body': text,
        'type': 'chat',
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งข้อความไม่สำเร็จ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
      builder: (context, receiverSnap) {
        final receiverData = (receiverSnap.data?.data() as Map<String, dynamic>?) ?? {};
        final displayName = receiverData['name'] ?? widget.receiverName;
        final avatarProvider = _getAvatarProvider(receiverData['avatar_url']);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      const Text('กำลังใช้งาน • ยืนยันตัวตนแล้ว', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatRoomId)
                      .collection('messages')
                      .orderBy('created_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'ทักทายคุณ $displayName เพื่อพูดคุยเรื่องสิ่งของได้เลย!',
                          style: TextStyle(color: Colors.blueGrey[400]),
                        ),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        final isMe = msg['sender_id'] == currentUserId;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.blue[100],
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF334155) : Colors.grey[200]),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 18),
                                  ),
                                ),
                                child: Text(
                                  msg['text'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'พิมพ์ข้อความ...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB),
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}