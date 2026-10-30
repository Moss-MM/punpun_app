import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

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

  // ระบบคำนวณยศ/ฉายาตามจำนวนการแบ่งปันและคะแนนความน่าเชื่อถือ
  Map<String, dynamic> _getRankBadge(int donations, int trustScore) {
    if (donations >= 5 || trustScore >= 140) {
      return {'title': '👑 ตำนานแห่งการแบ่งปัน', 'color': const Color(0xFFF59E0B)};
    } else if (donations >= 2 || trustScore >= 115) {
      return {'title': '⭐ นักปันน้ำใจดีเด่น', 'color': const Color(0xFF8B5CF6)};
    }
    return {'title': '🌱 ผู้เริ่มต้นแบ่งปัน', 'color': const Color(0xFF10B981)};
  }

  Widget _buildPodiumItem({
    required Map<String, dynamic> userData,
    required int rank,
    required double avatarRadius,
    required Color medalColor,
    required String medalEmoji,
  }) {
    final name = userData['name'] ?? 'สมาชิก';
    final score = userData['trust_score'] ?? 100;
    final donations = userData['donation_count'] ?? 0;
    final avatarProvider = _getAvatarProvider(userData['avatar_url']);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medalEmoji, style: TextStyle(fontSize: rank == 1 ? 28 : 22)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: medalColor, width: 3),
              boxShadow: [BoxShadow(color: medalColor.withAlpha(80), blurRadius: 10)],
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.white,
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: avatarRadius * 0.7, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score แต้ม ($donations ชิ้น)',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีข้อมูลจัดอันดับ'));
        }

        // เรียงลำดับจากคะแนนความน่าเชื่อถือ (trust_score) และจำนวนการบริจาค (donation_count)
        final users = snapshot.data!.docs.toList();
        users.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final scoreA = (dataA['trust_score'] ?? 100) as int;
          final scoreB = (dataB['trust_score'] ?? 100) as int;
          if (scoreB != scoreA) return scoreB.compareTo(scoreA);
          final donA = (dataA['donation_count'] ?? 0) as int;
          final donB = (dataB['donation_count'] ?? 0) as int;
          return donB.compareTo(donA);
        });

        return Column(
          children: [
            // 🏆 ส่วนหัว Podium Top 3 ดีไซน์ไล่สีสุดหรู
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const Text(
                    '🏆 หอเกียรติยศนักแบ่งปัน (Hall of Fame)',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'สะสมแต้มจากการโพสต์ให้สิ่งของและกดส่งมอบสำเร็จ',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // อันดับ 2 (ซ้าย)
                      if (users.length > 1)
                        _buildPodiumItem(
                          userData: users[1].data() as Map<String, dynamic>,
                          rank: 2,
                          avatarRadius: 28,
                          medalColor: const Color(0xFFE2E8F0),
                          medalEmoji: '🥈',
                        )
                      else
                        const Spacer(),

                      // อันดับ 1 (ตรงกลาง ใหญ่สุด)
                      if (users.isNotEmpty)
                        _buildPodiumItem(
                          userData: users[0].data() as Map<String, dynamic>,
                          rank: 1,
                          avatarRadius: 38,
                          medalColor: const Color(0xFFFBBF24),
                          medalEmoji: '👑',
                        ),

                      // อันดับ 3 (ขวา)
                      if (users.length > 2)
                        _buildPodiumItem(
                          userData: users[2].data() as Map<String, dynamic>,
                          rank: 3,
                          avatarRadius: 28,
                          medalColor: const Color(0xFFD97706),
                          medalEmoji: '🥉',
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 📋 ตารางจัดอันดับทั้งหมดพร้อมป้ายฉายาและไฮไลต์แถวของตัวเอง
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final doc = users[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isMe = doc.id == currentUserId;
                  final name = data['name'] ?? 'สมาชิกปันปัน';
                  final trustScore = (data['trust_score'] ?? 100) as int;
                  final donationCount = (data['donation_count'] ?? 0) as int;
                  final avatarProvider = _getAvatarProvider(data['avatar_url']);
                  final badge = _getRankBadge(donationCount, trustScore);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isMe ? const Color(0xFF2563EB) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: index < 3 ? const Color(0xFFF59E0B) : Colors.grey,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blue[100],
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('คุณ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (badge['color'] as Color).withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge['title'] as String,
                                style: TextStyle(
                                  color: badge['color'] as Color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$trustScore แต้ม',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981)),
                          ),
                          Text(
                            'แบ่งปัน $donationCount ครั้ง',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}