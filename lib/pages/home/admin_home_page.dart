import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../profile/profile_page.dart';
import '../chat/admin_inbox_page.dart';
import 'admin_dashboard_tab.dart';
import 'admin_applications_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int index = 0;

  static const Color primaryAdmin = Color(0xFF4F46E5);
  static const Color primaryAdminDark = Color(0xFF312E81);
  static const Color bgPage = Color(0xFFF5F7FA);

  @override
  Widget build(BuildContext context) {
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      return const Scaffold(
        body: Center(child: Text("กรุณาเข้าสู่ระบบ (admin)")),
      );
    }

    final pages = [
      const AdminDashboardTab(),
      const AdminApplicationsPage(),
      const AdminInboxPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: bgPage,

      // ✅ ไม่มี AppBar แล้ว
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Padding(
            key: ValueKey(index),
            padding: const EdgeInsets.all(16),
            child: pages[index],
          ),
        ),
      ),

      // ✅ Bottom Navigation Bar แบบสวยเหมือนเดิม
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _AdminBottomBar(
          currentIndex: index,
          onTap: (i) => setState(() => index = i),
        ),
      ),
    );
  }
}

class _AdminBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AdminBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color primaryAdmin = Color(0xFF4F46E5);
  static const Color primaryAdminDark = Color(0xFF312E81);
  static const Color inactive = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminBarItem(Icons.dashboard_rounded, "บอร์ด"),
      _AdminBarItem(Icons.assignment_ind_rounded, "ผู้สมัคร"),
      _AdminBarItem(Icons.inbox_rounded, "แชท"),
      _AdminBarItem(Icons.person_rounded, "โปรไฟล์"),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: primaryAdmin.withOpacity(.08),
              width: 1,
            ),
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
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? const LinearGradient(
                              colors: [primaryAdmin, primaryAdminDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: Row(
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

class _AdminBarItem {
  final IconData icon;
  final String label;
  const _AdminBarItem(this.icon, this.label);
}
