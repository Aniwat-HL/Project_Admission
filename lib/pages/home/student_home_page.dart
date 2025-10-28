import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../application/my_application_status_page.dart';
import '../chat/chat_page.dart';
import '../profile/profile_page.dart';
import 'home_dashboard_tab.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int index = 0;

  // สีธีมหลัก
  static const Color bgLight = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('กรุณาเข้าสู่ระบบก่อน')),
      );
    }

    final pages = [
      const HomeDashboardTab(),
      const MyApplicationStatusPage(),
      ChatPage(targetUserUid: uid, isAdminView: false),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: bgLight,

      // ไม่มี AppBar แล้ว ✅

      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: pages[index],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _FancyBottomBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
        ),
      ),
    );
  }
}

class _FancyBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FancyBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // สีปุ่ม bottom bar
  static const Color primary = Color(0xFF0D6EFD);
  static const Color primaryDark = Color(0xFF0044C8);
  static const Color inactive = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final items = [
      _BarItem(Icons.home_rounded, "หน้าแรก"),
      _BarItem(Icons.assignment_rounded, "สถานะ"),
      _BarItem(Icons.chat_bubble_rounded, "แชท"),
      _BarItem(Icons.person_rounded, "โปรไฟล์"),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? const LinearGradient(
                              colors: [
                                primary,
                                primaryDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          color: active ? Colors.white : inactive,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: active
                              ? Text(
                                  items[i].label,
                                  key: ValueKey(i),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BarItem {
  final IconData icon;
  final String label;
  const _BarItem(this.icon, this.label);
}
