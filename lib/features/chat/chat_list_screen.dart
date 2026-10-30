import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบเพื่อดูข้อความ'));
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'ข้อความสนทนา 💬',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_chat_unread_outlined, size: 70, color: Colors.blueGrey[300]),
                        const SizedBox(height: 16),
                        Text('ยังไม่มีประวัติการสนทนา', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
                      ],
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs.toList();
                allDocs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final timeA = dataA['updated_at'] as Timestamp?;
                  final timeB = dataB['updated_at'] as Timestamp?;
                  if (timeA == null && timeB == null) return 0;
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;
                  return timeB.compareTo(timeA);
                });

                final Set<String> seenUsers = {};
                final List<QueryDocumentSnapshot> uniqueChatDocs = [];
                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  final otherId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
                  if (otherId.isNotEmpty && !seenUsers.contains(otherId)) {
                    seenUsers.add(otherId);
                    uniqueChatDocs.add(doc);
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: uniqueChatDocs.length,
                  itemBuilder: (context, index) {
                    final doc = uniqueChatDocs[index];
                    final chatData = doc.data() as Map<String, dynamic>;
                    final participants = List<String>.from(chatData['participants'] ?? []);

                    final otherUserId = participants.firstWhere(
                      (id) => id != currentUserId,
                      orElse: () => '',
                    );

                    final lastMessage = chatData['last_message'] ?? 'เริ่มการสนทนา...';
                    final isUnread = chatData['unread_by'] == currentUserId || chatData['has_unread'] == true;

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
                      builder: (context, userSnapshot) {
                        String otherUserName = 'ผู้ใช้งาน';
                        String? avatarUrl;
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          otherUserName = userData?['name'] ?? 'ผู้ใช้งาน';
                          avatarUrl = userData?['avatar_url'];
                        }

                        final avatarProvider = _getAvatarProvider(avatarUrl);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.blue[100],
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? Text(
                                          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                                          style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 20),
                                        )
                                      : null,
                                ),
                                // จุดแดงเมื่อมีข้อความใหม่ หรือจุดเขียวออนไลน์
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: isUnread ? Colors.redAccent : const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    otherUserName,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'ข้อความใหม่',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isUnread ? Colors.blueAccent : Colors.grey,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            onTap: () {
                              doc.reference.update({'unread_by': '', 'has_unread': false});
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatRoomIdOverride: doc.id,
                                    receiverId: otherUserId,
                                    receiverName: otherUserName,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}