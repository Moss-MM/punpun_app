import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../post/create_post_screen.dart';
import '../post/post_detail_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/leaderboard_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../notification/notification_screen.dart';

ImageProvider? getAvatarImageProvider(String? avatarUrl) {
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

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  bool _isFirstLoad = true;

  final List<Widget> _screens = [
    const _FeedContent(),
    const LeaderboardScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForPopupBanner();
  }

  void _listenForPopupBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiver_id', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      if (!_isFirstLoad) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && data['is_read'] == false) {
              _showTopPopupNotification(
                title: data['title'] ?? 'การแจ้งเตือนใหม่',
                body: data['body'] ?? 'คุณมีข้อความใหม่',
                docRef: change.doc.reference,
                senderId: data['sender_id'],
                senderName: data['sender_name'],
              );
            }
          }
        }
      }
      _isFirstLoad = false;
    });
  }

  void _showTopPopupNotification({
    required String title,
    required String body,
    required DocumentReference docRef,
    String? senderId,
    String? senderName,
  }) {
    if (!mounted) return;
    SystemSound.play(SystemSoundType.alert);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        elevation: 8,
        backgroundColor: const Color(0xFF1E293B),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF3B82F6),
          child: Icon(Icons.notifications_active_rounded, color: Colors.white),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              docRef.update({'is_read': true});
              if (senderId != null && senderId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      receiverId: senderId,
                      receiverName: senderName ?? 'คู่สนทนา',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              }
            },
            child: const Text('เปิดดู', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            child: const Text('ปิด', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  // ฟังก์ชันเสกโพสต์ตัวอย่าง 2 สถานการณ์ตามใบงานโจทย์โบนัส (Nike + เจลแอลกอฮอล์ COVID-19)
  Future<void> _seedDemoScenarioPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    // สถานการณ์ที่ 1 (ข้อ b.i): แบ่งปันเจลแอลกอฮอล์และหน้ากากอนามัยช่วงขาดแคลน
    await FirebaseFirestore.instance.collection('posts').add({
      'owner_uid': user.uid,
      'title': 'แจกฟรี! เจลแอลกอฮอล์ 500ml และหน้ากากอนามัย 2 กล่อง',
      'description': 'สถานการณ์แพร่ระบาด COVID-19 ขาดแคลนเวชภัณฑ์ ขอแบ่งปันให้ผู้ที่เดือดร้อนและจำเป็นต้องใช้จริงๆ ครับ (ยืนยันตัวตนแล้ว ปลอดภัยไร้การโก่งราคา)',
      'post_type': 'ให้',
      'category': 'หน้ากากอนามัย/เจลแอลกอฮอล์/การแพทย์',
      'condition': 'ของใหม่ (100%)',
      'brand_size': '3M & แอลกอฮอล์ 75% ขนาด 500ml',
      'image_url': 'https://images.unsplash.com/photo-1584634731339-252c581abfc5?w=600&q=80',
      'expire_days': 7,
      'expires_at': Timestamp.fromDate(now.add(const Duration(days: 7))),
      'created_at': FieldValue.serverTimestamp(),
    });

    // สถานการณ์ที่ 2 (ข้อ a.iv & b.ii): รองเท้า Nike 1 คู่ ต้องการแลกสิ่งของใดๆ คล้ายแอป Swapup
    await FirebaseFirestore.instance.collection('posts').add({
      'owner_uid': user.uid,
      'title': 'รองเท้า Nike 1 คู่ ต้องการแลกสิ่งของใดๆ',
      'description': 'ใส่ไปแค่ 2 ครั้ง สภาพใหม่มาก ต้องการแลกกับสิ่งของใดๆ ก็ได้ที่ไม่ได้ใช้แล้ว (เช่น หนังสือเรียน, หูฟัง หรือกระเป๋า) ทักแชทมาคุยกันได้เลยครับ!',
      'post_type': 'แลก',
      'category': 'เสื้อผ้า/รองเท้า/แฟชั่น',
      'condition': 'มือสอง สภาพนางฟ้า (95%+)',
      'brand_size': 'Nike Air Force 1 ไซส์ 42',
      'image_url': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&q=80',
      'expire_days': 5,
      'expires_at': Timestamp.fromDate(now.add(const Duration(days: 5))),
      'created_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ เพิ่มโพสต์ตัวอย่างทั้ง 2 สถานการณ์ตามโจทย์เรียบร้อย!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('receiver_id', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, notifSnapshot) {
        int unreadNotifCount = 0;
        if (notifSnapshot.hasData) {
          for (var doc in notifSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['is_read'] == false) unreadNotifCount++;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: currentUserId)
              .snapshots(),
          builder: (context, chatSnapshot) {
            int unreadChatCount = 0;
            if (chatSnapshot.hasData) {
              for (var doc in chatSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['unread_by'] == currentUserId) unreadChatCount++;
              }
            }

            final totalChatBadge = unreadChatCount > 0 ? unreadChatCount : unreadNotifCount;

            return Scaffold(
              appBar: AppBar(
                title: const Row(
                  children: [
                    Icon(Icons.volunteer_activism_rounded, size: 26),
                    SizedBox(width: 8),
                    Text('PunPun'),
                  ],
                ),
                actions: [
                  // ⚡ ปุ่มเสกโพสต์ตัวอย่างตามโจทย์ (Nike + เจลแอลกอฮอล์)
                  IconButton(
                    tooltip: 'สร้างโพสต์ตัวอย่างตามโจทย์ (Nike & COVID-19)',
                    icon: const Icon(Icons.auto_awesome_rounded),
                    onPressed: _seedDemoScenarioPosts,
                  ),
                  // 🌙 ปุ่มสลับโหมดมืด / โหมดสว่าง
                  IconButton(
                    tooltip: 'สลับโหมดมืด/สว่าง',
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    onPressed: () {
                      themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                    },
                  ),
                  // 🔔 ปุ่มกระดิ่งแจ้งเตือนพร้อมจุดแดง
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 28),
                        onPressed: () {
                          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()));
                        },
                      ),
                      if (unreadNotifCount > 0 || unreadChatCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '${unreadNotifCount > 0 ? unreadNotifCount : unreadChatCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'ออกจากระบบ',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).clearMaterialBanners();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      }
                    },
                  ),
                ],
              ),
              body: _screens[_selectedIndex],
              floatingActionButton: _selectedIndex == 0
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostScreen()));
                      },
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('แบ่งปันสิ่งของ', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : null,
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'ฟีด',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined),
                    selectedIcon: Icon(Icons.emoji_events_rounded),
                    label: 'อันดับ',
                  ),
                  NavigationDestination(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded),
                        if (totalChatBadge > 0)
                          Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$totalChatBadge',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    selectedIcon: const Icon(Icons.chat_bubble_rounded),
                    label: 'แชท',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'โปรไฟล์',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedContent extends StatefulWidget {
  const _FeedContent();

  @override
  State<_FeedContent> createState() => _FeedContentState();
}

class _FeedContentState extends State<_FeedContent> {
  String _selectedFilter = 'ทั้งหมด';
  final List<String> _filters = ['ทั้งหมด', 'ให้', 'ขอรับ', 'แลก'];

  // ตัวกรองตามหมวดสินค้า (ตามโจทย์ข้อ a.v)
  String _selectedCategory = 'ทุกหมวดหมู่';
  final List<String> _categories = [
    'ทุกหมวดหมู่',
    'เสื้อผ้า/รองเท้า/แฟชั่น',
    'หน้ากากอนามัย/เจลแอลกอฮอล์/การแพทย์',
    'หนังสือ/การเรียน',
    'อุปกรณ์อิเล็กทรอนิกส์',
    'ของใช้ในบ้าน/หอพัก',
    'อุปกรณ์กีฬา',
    'อื่นๆ'
  ];

  String _searchQuery = '';

  // ฟังก์ชันกดปุ่ม "สนใจ" แล้วแจ้งเตือน Push Notification เด้งทันที (ตามโจทย์ข้อ a.vi)
  Future<void> _sendInterestNotification(Map<String, dynamic> postData, String ownerUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String myName = currentUser.email?.split('@').first ?? 'สมาชิกปันปัน';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (doc.exists) myName = doc.data()?['name'] ?? myName;
    } catch (_) {}

    final targetUid = ownerUid.isNotEmpty ? ownerUid : currentUser.uid;
    final postTitle = postData['title'] ?? 'สิ่งของของคุณ';

    // ยิงแจ้งเตือนหาเจ้าของโพสต์
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiver_id': targetUid,
      'sender_id': currentUser.uid,
      'sender_name': myName,
      'title': 'มีคนสนใจโพสต์ของคุณ! ❤️',
      'body': 'คุณ $myName สนใจ "$postTitle" ทักแชทเพื่อพูดคุยได้เลย!',
      'type': 'interest',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    // ถ้ายิงหาคนอื่น ให้จำลองเด้งบนเครื่องตัวเองด้วยเผื่อตอนสาธิตเครื่องเดียวให้เห็น Popup ทันที
    if (targetUid != currentUser.uid) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiver_id': currentUser.uid,
        'sender_id': targetUid,
        'sender_name': 'ระบบแจ้งเตือนปันปัน',
        'title': 'ส่งความสนใจสำเร็จ! ❤️',
        'body': 'แจ้งเตือนไปยังผู้โพสต์ "$postTitle" เรียบร้อยแล้ว',
        'type': 'interest',
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _markPostAsCompleted(BuildContext context, String docId, String ownerUid) async {
    await FirebaseFirestore.instance.collection('posts').doc(docId).update({
      'is_completed': true,
    });
    await FirebaseFirestore.instance.collection('users').doc(ownerUid).set({
      'trust_score': FieldValue.increment(10),
      'donation_count': FieldValue.increment(1),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 ส่งมอบสิ่งของสำเร็จ! คุณได้รับ +10 คะแนนความน่าเชื่อถือ!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showUserProfileModal(BuildContext context, Map<String, dynamic> userData, String userId) {
    final name = userData['name'] ?? 'สมาชิกปันปัน';
    final bio = userData['bio'] ?? 'มาร่วมแบ่งปันสิ่งดีๆ ให้สังคมน่าอยู่ขึ้นกันเถอะ 🌱';
    final trustScore = userData['trust_score'] ?? 100;
    final donationCount = userData['donation_count'] ?? 0;
    final avatarProvider = getAvatarImageProvider(userData['avatar_url']);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue[100],
              backgroundImage: avatarProvider,
              child: avatarProvider == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent))
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Chip(
                  avatar: const Icon(Icons.shield_rounded, color: Colors.green, size: 18),
                  label: Text('ความน่าเชื่อถือ: $trustScore'),
                ),
                Chip(
                  avatar: const Icon(Icons.volunteer_activism_rounded, color: Colors.pinkAccent, size: 18),
                  label: Text('แบ่งปันแล้ว: $donationCount ครั้ง'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (userId != currentUserId)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatScreen(receiverId: userId, receiverName: name)),
                  );
                },
                icon: const Icon(Icons.chat_bubble_rounded),
                label: Text('ทักแชทหาคุณ $name'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 1. ช่องค้นหา + ตัวกรองหมวดหมู่สินค้า (โจทย์ข้อ a.v)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา (เช่น Nike, เจลแอลกอฮอล์)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ปุ่มเลือกกรองตามหมวดสินค้า
              PopupMenuButton<String>(
                tooltip: 'กรองตามหมวดสินค้า',
                onSelected: (val) => setState(() => _selectedCategory = val),
                itemBuilder: (context) => _categories
                    .map((cat) => PopupMenuItem(
                          value: cat,
                          child: Row(
                            children: [
                              Icon(
                                _selectedCategory == cat ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: Colors.blueAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cat, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedCategory == 'ทุกหมวดหมู่'
                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _selectedCategory == 'ทุกหมวดหมู่'
                        ? (isDark ? Colors.white : Colors.blueAccent)
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. ปุ่มกรองประเภทโพสต์ (ทั้งหมด / ให้ / ขอรับ / แลก)
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = _selectedFilter == filter;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedFilter = filter);
                  },
                ),
              );
            },
          ),
        ),

        if (_selectedCategory != 'ทุกหมวดหมู่')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.category_rounded, size: 15, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'หมวดสินค้า: $_selectedCategory',
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedCategory = 'ทุกหมวดหมู่'),
                  child: const Text('ล้างตัวกรอง', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

        // 3. รายการโพสต์ในฟีด
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('posts').orderBy('created_at', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.blueGrey[300]),
                      const SizedBox(height: 16),
                      Text('ยังไม่มีสิ่งของถูกโพสต์ในขณะนี้', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
                    ],
                  ),
                );
              }

              final allPosts = snapshot.data!.docs;
              final now = DateTime.now();

              final filteredPosts = allPosts.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final expiresAt = data['expires_at'] as Timestamp?;
                if (expiresAt != null && expiresAt.toDate().isBefore(now)) {
                  return false;
                }

                bool matchType = _selectedFilter == 'ทั้งหมด' || data['post_type'] == _selectedFilter;
                bool matchCatDropdown = _selectedCategory == 'ทุกหมวดหมู่' ||
                    (data['category'] ?? '').toString().contains(_selectedCategory.split('/').first);

                String title = (data['title'] ?? '').toString().toLowerCase();
                String desc = (data['description'] ?? '').toString().toLowerCase();
                String cat = (data['category'] ?? '').toString().toLowerCase();
                String brand = (data['brand_size'] ?? '').toString().toLowerCase();
                bool matchSearch = _searchQuery.isEmpty ||
                    title.contains(_searchQuery) ||
                    desc.contains(_searchQuery) ||
                    cat.contains(_searchQuery) ||
                    brand.contains(_searchQuery);

                return matchType && matchCatDropdown && matchSearch;
              }).toList();

              if (filteredPosts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.blueGrey[300]),
                      const SizedBox(height: 16),
                      Text('ไม่พบโพสต์ที่ตรงกับเงื่อนไข', style: TextStyle(color: Colors.blueGrey[400], fontSize: 16)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 90),
                itemCount: filteredPosts.length,
                itemBuilder: (context, index) {
                  final docId = filteredPosts[index].id;
                  final data = filteredPosts[index].data() as Map<String, dynamic>;

                  final postType = data['post_type'] ?? 'ให้';
                  Color typeColor = const Color(0xFF10B981);
                  if (postType == 'ขอรับ') typeColor = const Color(0xFFF59E0B);
                  if (postType == 'แลก') typeColor = const Color(0xFF8B5CF6);

                  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                  final ownerUid = (data['owner_uid'] ?? data['user_id'] ?? '').toString();
                  final isMyPost = ownerUid == currentUserId;
                  final isCompleted = data['is_completed'] == true;

                  String expireText = '';
                  final expiresAt = data['expires_at'] as Timestamp?;
                  if (expiresAt != null) {
                    final daysLeft = expiresAt.toDate().difference(now).inDays + 1;
                    expireText = 'เหลือ $daysLeft วัน';
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(docId: docId, data: data)));
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: ownerUid.isNotEmpty
                                ? FirebaseFirestore.instance.collection('users').doc(ownerUid).snapshots()
                                : null,
                            builder: (context, userSnap) {
                              final userData = (userSnap.data?.data() as Map<String, dynamic>?) ?? {};
                              final ownerName = userData['name'] ?? (isMyPost ? 'ฉัน (โพสต์ของคุณ)' : 'สมาชิกปันปัน');
                              final avatarProvider = getAvatarImageProvider(userData['avatar_url']);

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (ownerUid.isNotEmpty) {
                                          _showUserProfileModal(context, userData, ownerUid);
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 19,
                                            backgroundColor: Colors.blue[100],
                                            backgroundImage: avatarProvider,
                                            child: avatarProvider == null
                                                ? Text(
                                                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    ownerName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 15),
                                                  if (isMyPost) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withAlpha(30),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text('คุณ', style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                data['category'] ?? 'หมวดหมู่ทั่วไป',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.grey.withAlpha(40) : typeColor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isCompleted ? Colors.grey : typeColor),
                                      ),
                                      child: Text(
                                        isCompleted ? 'ส่งมอบแล้ว 🎉' : postType,
                                        style: TextStyle(
                                          color: isCompleted ? Colors.grey : typeColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          if (data['image_url'] != null && data['image_url'].toString().isNotEmpty)
                            Builder(
                              builder: (context) {
                                final imgStr = data['image_url'].toString();
                                if (imgStr.startsWith('data:image')) {
                                  try {
                                    return Image.memory(
                                      base64Decode(imgStr.split(',').last),
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    );
                                  } catch (_) {}
                                }
                                return Image.network(
                                  imgStr,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 150,
                                    width: double.infinity,
                                    color: Colors.blue.withAlpha(20),
                                    child: Icon(Icons.image_outlined, size: 50, color: Colors.blue[200]),
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              height: 130,
                              width: double.infinity,
                              color: Colors.blue.withAlpha(20),
                              child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.blue[300]),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] ?? 'ไม่มีชื่อสิ่งของ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (expireText.isNotEmpty && !isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withAlpha(25),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, size: 13, color: Colors.redAccent),
                                            const SizedBox(width: 4),
                                            Text(expireText, style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (data['condition'] != null || (data['brand_size'] != null && data['brand_size'].toString().isNotEmpty))
                                  Text(
                                    'สภาพ: ${data['condition'] ?? '-'} ${data['brand_size'] != null && data['brand_size'].toString().isNotEmpty ? '• ขนาด/ยี่ห้อ: ${data['brand_size']}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  data['description'] ?? 'ไม่มีรายละเอียด',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey, height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    // ❤️ ปุ่ม "สนใจ" กดปุ๊บเด้งแจ้งเตือน Push Notification ทันที (โจทย์ข้อ a.vi)
                                    if (!isCompleted)
                                      OutlinedButton.icon(
                                        onPressed: () => _sendInterestNotification(data, ownerUid),
                                        icon: const Icon(Icons.favorite_rounded, size: 16, color: Colors.pinkAccent),
                                        label: const Text('สนใจ', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.pinkAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      ),
                                    if (!isMyPost && !isCompleted)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          String ownerName = 'ผู้โพสต์';
                                          try {
                                            final doc = await FirebaseFirestore.instance.collection('users').doc(ownerUid).get();
                                            if (doc.exists) ownerName = doc.data()?['name'] ?? 'ผู้โพสต์';
                                          } catch (_) {}

                                          if (context.mounted) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatScreen(
                                                  receiverId: ownerUid,
                                                  receiverName: ownerName,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                                        label: const Text('ทักแชท', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          elevation: 0,
                                        ),
                                      )
                                    else if (isMyPost && !isCompleted)
                                      OutlinedButton.icon(
                                        onPressed: () => _markPostAsCompleted(context, docId, ownerUid),
                                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.green),
                                        label: const Text('ส่งมอบสำเร็จ (+10)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.green),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      )
                                    else if (isCompleted)
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                                          SizedBox(width: 4),
                                          Text('แบ่งปันสำเร็จแล้ว', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}