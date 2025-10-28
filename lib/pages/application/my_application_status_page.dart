import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/application_record.dart';
import '../chat/chat_page.dart';

class MyApplicationStatusPage extends StatelessWidget {
  const MyApplicationStatusPage({super.key});

  // --- Theme tokens (match app) ---
  static const Color bgPage = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMute = Color(0xFF6B7280);
  static const Color borderSoft = Color(0x14000000); // 8% black
  static const Color cardBG = Colors.white;
  static const Color primaryBlue = Color(0xFF2563EB);

  Color _statusColor(String status) {
    switch (status) {
      case "pending_docs":
        return const Color(0xFFEA580C); // ส้ม
      case "waiting_verify":
        return const Color(0xFF2563EB); // ฟ้า
      case "approved":
        return const Color(0xFF10B981); // เขียว
      case "rejected":
        return const Color(0xFFEF4444); // แดง
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "pending_docs":
        return "ส่งใบสมัครแล้ว";
      case "waiting_verify":
        return "กำลังตรวจการชำระเงิน";
      case "approved":
        return "ยืนยันแล้ว 🎉";
      case "rejected":
        return "ไม่ผ่าน";
      default:
        return status;
    }
  }

  // 12/10/2025 14:30
  String _formatDate(int ms) {
    if (ms == 0) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final nn = dt.minute.toString().padLeft(2, '0');

    return "$dd/$mm/$yyyy $hh:$nn";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "กรุณาเข้าสู่ระบบก่อน",
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 56,
        titleSpacing: 16,
        centerTitle: false,
        title: const Text(
          "สถานะการสมัครของฉัน",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      body: StreamBuilder<List<ApplicationRecord>>(
        stream: fs.watchMyApplications(uid),
        builder: (context, snap) {
          // Loading state
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Error state
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "โหลดข้อมูลไม่สำเร็จ:\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }

          final apps = snap.data ?? [];

          // Empty state (ยังไม่เคยสมัคร)
          if (apps.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBG,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: primaryBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "ยังไม่มีใบสมัคร",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "ไปเลือกคอร์สที่สนใจจากหน้าแรก\nแล้วกด “สมัครคอร์สนี้” ได้เลย ✍️",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: textMute,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // List of applications
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final a = apps[i];
              final statusClr = _statusColor(a.status);
              final statusText = _statusLabel(a.status);
              final submittedText = _formatDate(a.submittedAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardBG,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: borderSoft,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนหัว: ชื่อคอร์ส + badge สถานะ
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ชื่อคอร์ส
                        Expanded(
                          child: Text(
                            a.courseName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: textDark,
                              height: 1.3,
                            ),
                          ),
                        ),

                        // badge สถานะ
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusClr.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusClr.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: statusClr,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusClr,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // วันที่สมัคร
                    Text(
                      "ส่งใบสมัครเมื่อ $submittedText",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.black.withOpacity(0.05),
                    ),
                    const SizedBox(height: 16),

                    // เนื้อหาแนะนำขั้นถัดไป + ปุ่ม
                    _NextStepSection(
                      uid: uid,
                      status: a.status,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NextStepSection extends StatelessWidget {
  final String uid;
  final String status;
  const _NextStepSection({
    required this.uid,
    required this.status,
  });

  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    // สถานะต่าง ๆ
    if (status == "pending_docs") {
      // สมัครแล้วแต่ยังไม่ส่งสลิป
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ขั้นตอนถัดไป",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "• โอนค่าเรียนตามที่เจ้าหน้าที่แจ้ง\n"
            "• ส่งสลิปโอน (รูปภาพ) ให้เจ้าหน้าที่ในห้องแชท 💳",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.chat,
            label: "เปิดแชทเพื่อส่งสลิป",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    targetUserUid: uid,
                    isAdminView: false,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    if (status == "waiting_verify") {
      // ส่งสลิปแล้ว รอแอดมินตรวจ
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "กำลังตรวจสอบการชำระเงิน 👀",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "ถ้าต้องการแก้ไขหรือสอบถามเพิ่มเติม สามารถคุยกับเจ้าหน้าที่ได้ทันที",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _GhostActionButton(
            icon: Icons.chat_bubble_outline,
            label: "คุยกับเจ้าหน้าที่",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    targetUserUid: uid,
                    isAdminView: false,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    if (status == "approved") {
      // ผ่านแล้ว
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ยืนยันเรียบร้อยแล้ว 🎉",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "เจ้าหน้าที่จะส่งรายละเอียดวันเรียน / กลุ่มเรียน / ลิงก์เข้าห้องเรียน ให้ในแชท",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _GhostActionButton(
            icon: Icons.chat_bubble,
            label: "เปิดแชท",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    targetUserUid: uid,
                    isAdminView: false,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    if (status == "rejected") {
      // ไม่ผ่าน
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "สถานะใบสมัคร",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "ใบสมัครของคุณไม่ผ่านการอนุมัติ หากต้องการสอบถามรายละเอียดเพิ่มเติม สามารถคุยกับเจ้าหน้าที่ได้",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _GhostActionButton(
            icon: Icons.chat_bubble_outline,
            label: "สอบถามเพิ่มเติม",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    targetUserUid: uid,
                    isAdminView: false,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // fallback สถานะที่ไม่รู้จัก
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "สถานะใบสมัคร",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "สถานะปัจจุบัน: $status",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ปุ่ม action หลัก (ฟ้าเต็ม)
class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ปุ่มรอง (ขอบฟ้า / ghost)
class _GhostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GhostActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(
          icon,
          color: primaryBlue,
          size: 20,
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primaryBlue,
          ),
        ),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: primaryBlue.withOpacity(.4),
            width: 1.2,
          ),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
