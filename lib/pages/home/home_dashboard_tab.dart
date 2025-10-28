import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/course.dart';
import '../home/course_detail_page.dart';

class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({super.key});

  // ----------- helper format เวลา/วันที่ ให้สวยขึ้น -----------
  String _formatDateRange(Course c) {
    // ถ้ามี startDate / endDate ให้โชว์ช่วงวันที่
    if (c.startDate != null && c.endDate != null) {
      final df = DateFormat('d MMM yyyy'); // 10 Nov 2025
      final start = df.format(c.startDate!);
      final end = df.format(c.endDate!);

      // เวลาเรียน
      final timeStr = (c.startTime != null && c.endTime != null)
          ? "${c.startTime} - ${c.endTime}"
          : c.schedule;

      return "$start - $end • $timeStr";
    }

    // fallback ถ้ายังไม่มีข้อมูลใหม่
    return c.schedule.isNotEmpty ? c.schedule : "-";
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final displayName = (authUser?.displayName?.trim().isNotEmpty ?? false)
        ? authUser!.displayName!.trim()
        : "นักเรียน";

    final fs = FirestoreService();

    // โทนสีหลัก
    const primaryBlue = Color(0xFF2563EB);
    const bgSoftBlue = Color(0xFFEAF4FF);

    return Container(
      color: const Color(0xFFF5F7FA),
      child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // --------- HEADER CARD (ฟ้ากลมมน + avatar) ----------
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEAF4FF),
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
                border: Border.all(
                  color: primaryBlue.withOpacity(0.06),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // avatar วงกลม
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: primaryBlue.withOpacity(0.1),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ข้อความทักทาย
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "สวัสดี, $displayName 👋",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "เลือกคอร์สที่สนใจแล้วกดสมัครได้เลย",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------- TITLE SECTION ----------
            const Text(
              "คอร์สที่เปิดรับสมัคร",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- LIST COURSES (StreamBuilder) ----------
            StreamBuilder<List<Course>>(
              stream: fs.watchOpenCourses(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "โหลดคอร์สไม่สำเร็จ: ${snap.error}",
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final courses = snap.data ?? [];
                if (courses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black.withOpacity(0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "ตอนนี้ยังไม่มีคอร์สที่เปิดรับสมัคร\nกลับมาตรวจสอบใหม่เร็ว ๆ นี้นะ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final c in courses) ...[
                      _CourseCard(
                        course: c,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseDetailPage(courseId: c.id),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// การ์ดคอร์สแบบ product card / modern marketplace style
// -------------------------------------------------------------
class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);

    final priceText = course.price > 0
        ? "${course.price.toStringAsFixed(0)} บาท"
        : "ฟรี";

    final scheduleText = _buildSchedule(course);

    final bool isOpen = course.isOpen;
    final badgeColor = isOpen ? const Color(0xFFE8FEE6) : const Color(0xFFFFF4E5);
    final badgeTextColor = isOpen ? const Color(0xFF15803D) : const Color(0xFF92400E);
    final badgeIcon = isOpen ? Icons.check_circle : Icons.lock_clock;
    final badgeText = isOpen ? "เปิดรับสมัคร" : "ปิดรับสมัคร";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1st row: title + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ชื่อคอร์ส
              Expanded(
                child: Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Badge สถานะ
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeTextColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      badgeIcon,
                      size: 14,
                      color: badgeTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ราคา
          Text(
            priceText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: primaryBlue,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          // เวลาเรียน / วัน
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calendar_month,
                size: 16,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scheduleText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ปุ่มดูรายละเอียด
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: BorderSide(
                  color: primaryBlue.withOpacity(0.3),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onTap,
              child: const Text(
                "ดูรายละเอียดคอร์ส",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

static String _buildSchedule(Course c) {
  if (c.startDate != null &&
      c.endDate != null &&
      c.startTime != null &&
      c.endTime != null) {
    // พยายาม format แบบไทยก่อน
    try {
      final dfTh = DateFormat('d MMM yyyy', 'th_TH');
      final startTh = dfTh.format(c.startDate!);
      final endTh = dfTh.format(c.endDate!);
      return "$startTh - $endTh เวลา ${c.startTime} - ${c.endTime}";
    } catch (_) {
      // ถ้ายังไม่ได้ initializeDateFormatting (เช่นกรณีรันด้วย hot reload)
      final dfFallback = DateFormat('d MMM yyyy'); // ไม่มี locale -> en-ish
      final startEn = dfFallback.format(c.startDate!);
      final endEn = dfFallback.format(c.endDate!);
      return "$startEn - $endEn เวลา ${c.startTime} - ${c.endTime}";
    }
  }

  if (c.schedule.isNotEmpty) {
    return c.schedule;
  }

  return "-";
}

}
