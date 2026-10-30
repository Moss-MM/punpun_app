import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';
import '../post/post_detail_screen.dart';
import '../post/create_post_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('กรุณาเข้าสู่ระบบ'));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
        final name = userData['name'] ?? user.email?.split('@').first ?? 'สมาชิกปันปัน';
        final email = userData['email'] ?? user.email ?? '';
        final bio = userData['bio'] ?? 'มาร่วมแบ่งปันสิ่งดีๆ ให้สังคมน่าอยู่ขึ้นกันเถอะ 🌱';
        final phone = userData['phone'] ?? '';
        final trustScore = userData['trust_score'] ?? 100;
        final bannerColorHex = userData['banner_color'] ?? 0xFF2196F3;
        final avatarUrl = userData['avatar_url'] as String?;

        ImageProvider? avatarProvider;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          try {
            if (avatarUrl.startsWith('data:image')) {
              avatarProvider = MemoryImage(base64Decode(avatarUrl.split(',').last));
            } else {
              avatarProvider = NetworkImage(avatarUrl);
            }
          } catch (_) {}
        }

        // ดึงโพสต์ทั้งหมดมาเช็กในฝั่งแอป เพื่อให้เจอโพสต์ของเรา 100% และนับจำนวนโพสต์ได้ตรงเป๊ะ!
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').snapshots(),
          builder: (context, postSnapshot) {
            List<QueryDocumentSnapshot> myPosts = [];

            if (postSnapshot.hasData) {
              myPosts = postSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // เช็กครอบคลุมทุกชื่อตัวแปรที่เป็นไปได้ (รองรับทั้งโพสต์เก่าและโพสต์ใหม่)
                return data['owner_uid'] == user.uid ||
                    data['user_id'] == user.uid ||
                    data['uid'] == user.uid ||
                    data['author_id'] == user.uid ||
                    (user.email != null && data['owner_email'] == user.email) ||
                    (user.email != null && data['email'] == user.email);
              }).toList();

              // เรียงโพสต์จากใหม่สุดไปเก่าสุด
              myPosts.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;
                final timeA = dataA['created_at'] as Timestamp?;
                final timeB = dataB['created_at'] as Timestamp?;
                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;
                return timeB.compareTo(timeA);
              });
            }

            final int postCount = myPosts.length;
            final int displayDonationCount = (userData['donation_count'] ?? 0) > postCount
                ? (userData['donation_count'] as int)
                : postCount;

            return SingleChildScrollView(
              child: Column(
                children: [
                  // 1. ส่วนปก Banner + รูปโปรไฟล์ + ปุ่มแก้ไข
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 130,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(bannerColorHex),
                              Color(bannerColorHex).withAlpha(180),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 16,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(currentData: userData),
                              ),
                            );
                          },
                          icon: const Icon(Icons.palette_outlined, size: 16),
                          label: const Text('แต่งโปรไฟล์'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(bannerColorHex),
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -45,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(currentData: userData),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.blue[50],
                              backgroundImage: avatarProvider,
                              child: avatarProvider == null
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(bannerColorHex)),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 54),

                  // 2. ชื่อ + ป้ายยืนยันบัตรประชาชน + Bio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'ยืนยันบัตรประชาชนแล้ว',
                        child: Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(email, style: TextStyle(color: Colors.blueGrey[400], fontSize: 13)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Color(bannerColorHex)),
                        const SizedBox(width: 4),
                        Text(phone, style: TextStyle(color: Color(bannerColorHex), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey[700], fontSize: 14),
                    ),
                  ),

                  // 3. การ์ดสถิติความน่าเชื่อถือและการแบ่งปัน
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.shield_rounded, color: Colors.green, size: 26),
                              const SizedBox(height: 4),
                              Text('$trustScore', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                              const Text('ความน่าเชื่อถือ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          Container(height: 40, width: 1, color: Colors.grey[300]),
                          Column(
                            children: [
                              const Icon(Icons.volunteer_activism_rounded, color: Colors.pinkAccent, size: 26),
                              const SizedBox(height: 4),
                              Text('$displayDonationCount รายการ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
                              const Text('โพสต์แบ่งปัน', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          Container(height: 40, width: 1, color: Colors.grey[300]),
                          const Column(
                            children: [
                              Icon(Icons.badge_rounded, color: Colors.blueAccent, size: 26),
                              SizedBox(height: 4),
                              Text('Verified', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                              Text('ยืนยันตัวตนแล้ว', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('โพสต์ของฉัน ($postCount)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreatePostScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('สร้างโพสต์ใหม่'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 4. แสดงรายการโพสต์ของฉัน
                  if (postSnapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    )
                  else if (myPosts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('คุณยังไม่มีโพสต์สิ่งของในบัญชีนี้', style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: myPosts.length,
                      itemBuilder: (context, index) {
                        final doc = myPosts[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final imageUrl = data['image_url'] as String?;
                        final postType = data['post_type'] ?? 'ให้';

                        Color badgeColor = Colors.green;
                        if (postType == 'ขอรับ') badgeColor = Colors.orange;
                        if (postType == 'แลก') badgeColor = Colors.purple;

                        Widget leadingImage = Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent),
                        );

                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          try {
                            if (imageUrl.startsWith('data:image')) {
                              leadingImage = ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(imageUrl.split(',').last),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              );
                            } else {
                              leadingImage = ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.inventory_2_outlined, color: Colors.blueAccent),
                                  ),
                                ),
                              );
                            }
                          } catch (_) {}
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: leadingImage,
                            title: Text(
                              data['title'] ?? 'ไม่มีชื่อสิ่งของ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      postType,
                                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data['category'] ?? 'ทั่วไป',
                                      style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'ลบโพสต์',
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('ยืนยันการลบโพสต์'),
                                    content: Text('ต้องการลบโพสต์ "${data['title'] ?? ''}" ใช่หรือไม่?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('ลบโพสต์', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await doc.reference.delete();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ลบโพสต์เรียบร้อยแล้ว')),
                                    );
                                  }
                                }
                              },
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(docId: doc.id, data: data),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
}