import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // ฟังก์ชันแปลงเวลาเป็น "กี่นาทีที่แล้ว" แบบแอปดัง
  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'เพิ่งเมื่อครู่';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'เพิ่งเมื่อครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  // ไอคอนและสีตามประเภทของการแจ้งเตือน
  Map<String, dynamic> _getIconForType(String? type) {
    switch (type) {
      case 'interest':
        return {'icon': Icons.favorite_rounded, 'color': Colors.pinkAccent, 'bg': Colors.pink[50]};
      case 'chat':
        return {'icon': Icons.chat_bubble_rounded, 'color': const Color(0xFF2563EB), 'bg': Colors.blue[50]};
      case 'match':
        return {'icon': Icons.auto_awesome_rounded, 'color': const Color(0xFFF59E0B), 'bg': Colors.amber[50]};
      default:
        return {'icon': Icons.notifications_rounded, 'color': const Color(0xFF10B981), 'bg': Colors.green[50]};
    }
  }

  Future<void> _sendTestNotification(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final types = ['interest', 'chat', 'match'];
    final type = types[DateTime.now().second % 3]; // สุ่มประเภทให้ดูหลากหลาย

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiver_id': user.uid,
      'sender_id': user.uid,
      'sender_name': 'สมาชิกปันปัน',
      'title': type == 'interest' ? 'มีคนสนใจโพสต์ของคุณ! ❤️' : type == 'chat' ? 'ข้อความใหม่ 💬' : 'โพสต์ใหม่ตรงใจคุณ ✨',
      'body': 'นี่คือการแจ้งเตือนทดสอบ เพื่อให้เห็นความสวยงามของ UI',
      'type': type,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ ส่งการแจ้งเตือนจำลองสำเร็จ!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // แถบด้านบนแบบ Sliver ดูลื่นไหล
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'การแจ้งเตือน 🔔',
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 22),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'อ่านทั้งหมด',
                icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                onPressed: () async {
                  if (currentUserId == null) return;
                  final batch = FirebaseFirestore.instance.batch();
                  final snaps = await FirebaseFirestore.instance.collection('notifications').where('receiver_id', isEqualTo: currentUserId).get();
                  for (var doc in snaps.docs) {
                    batch.update(doc.reference, {'is_read': true});
                  }
                  await batch.commit();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          
          // ส่วนเนื้อหา
          SliverFillRemaining(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('receiver_id', isEqualTo: currentUserId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('notifications').where('receiver_id', isEqualTo: currentUserId).snapshots(),
                    builder: (context, fallbackSnap) {
                      if (!fallbackSnap.hasData || fallbackSnap.data!.docs.isEmpty) return _buildEmptyState(context, isDark);
                      return _buildList(fallbackSnap.data!.docs, context, isDark);
                    },
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(context, isDark);
                }

                return _buildList(snapshot.data!.docs, context, isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _sendTestNotification(context),
        backgroundColor: const Color(0xFF2563EB),
        tooltip: 'จำลองการแจ้งเตือน',
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      ),
    );
  }

  // หน้าจอตอนไม่มีการแจ้งเตือน (สวยๆ คลีนๆ)
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF1E293B) : Colors.blue[50],
            ),
            child: Icon(Icons.notifications_off_rounded, size: 80, color: isDark ? Colors.blueGrey[400] : Colors.blue[200]),
          ),
          const SizedBox(height: 24),
          Text(
            'ยังไม่มีความเคลื่อนไหว',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'การแจ้งเตือนทั้งหมดของคุณจะแสดงที่นี่',
            style: TextStyle(color: Colors.blueGrey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  // รายการแจ้งเตือนสุดพรีเมียม
  Widget _buildList(List<QueryDocumentSnapshot> docs, BuildContext context, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final isRead = data['is_read'] ?? false;
        final title = data['title'] ?? 'แจ้งเตือนใหม่';
        final body = data['body'] ?? '';
        final type = data['type'] as String?;
        final timeStr = _timeAgo(data['created_at'] as Timestamp?);
        
        final iconProps = _getIconForType(type);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key(doc.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
            ),
            onDismissed: (direction) {
              doc.reference.delete();
            },
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                doc.reference.update({'is_read': true});
                final senderId = data['sender_id'];
                if (senderId != null && senderId.toString().isNotEmpty && senderId != FirebaseAuth.instance.currentUser?.uid) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        receiverId: senderId,
                        receiverName: data['sender_name'] ?? 'คู่สนทนา',
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRead 
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white) 
                      : (isDark ? const Color(0xFF1E293B).withAlpha(150) : iconProps['bg']),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRead 
                        ? (isDark ? const Color(0xFF334155) : Colors.grey.shade200) 
                        : iconProps['color'].withAlpha(100),
                    width: isRead ? 1 : 1.5,
                  ),
                  boxShadow: [
                    if (!isRead && !isDark) 
                      BoxShadow(color: iconProps['color'].withAlpha(20), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ไอคอนด้านซ้าย
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? (isDark ? const Color(0xFF334155) : Colors.grey[100]) : iconProps['color'].withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconProps['icon'], 
                        color: isRead ? Colors.grey : iconProps['color'],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // เนื้อหา
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w900, 
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11, 
                                  color: isRead ? Colors.grey : iconProps['color'],
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.blueGrey[700], 
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // จุดแดง (ถ้ายังไม่อ่าน)
                    if (!isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: iconProps['color'],
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: iconProps['color'].withAlpha(100), blurRadius: 4)],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}