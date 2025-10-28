import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/course.dart';
import 'edit_course_page.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  static const Color bgPage = Color(0xFFF5F7FA);
  static const Color cardBorder = Color(0x14000000);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color purple = Color(0xFF4F46E5);
  static const Color purpleDark = Color(0xFF312E81);
  static const Color green = Color(0xFF10B981);
  static const Color greenDark = Color(0xFF065F46);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueDark = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Stack(
      children: [
        Container(color: bgPage),

        StreamBuilder<List<Course>>(
          stream: fs.watchAllCoursesForAdmin(),
          builder: (context, snapCourses) {
            if (snapCourses.connectionState == ConnectionState.waiting &&
                !snapCourses.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapCourses.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "โหลดข้อมูลคอร์สไม่สำเร็จ:\n${snapCourses.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final courses = snapCourses.data ?? [];
            final totalCourses = courses.length;
            final openCourses =
                courses.where((c) => c.isOpen == true).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 110),
              children: [
                // HEADER
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "แดชบอร์ดแอดมิน",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "ภาพรวมคอร์ส ผู้สมัคร รายได้ และผู้ใช้งาน",
                        style: TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== สถิติจำนวนคอร์ส / ผู้ใช้ / รายได้รวม =====
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // การ์ดคอร์สทั้งหมด
                      Expanded(
                        child: _StatCard(
                          icon: Icons.school_rounded,
                          value: "$totalCourses",
                          label: "คอร์สทั้งหมด",
                          gradientColors: const [purple, purpleDark],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // การ์ดจำนวนผู้ใช้ (นักเรียนทั้งหมด)
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: fs.watchTotalUsers(),
                          builder: (context, snapUsers) {
                            final totalUsers =
                                snapUsers.data?.toString() ?? "-";

                            return _StatCard(
                              icon: Icons.people_alt_rounded,
                              value: totalUsers,
                              label: "ผู้ใช้งานแอป",
                              gradientColors: const [blue, blueDark],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      // การ์ดคอร์สที่เปิดรับ
                      Expanded(
                        child: _StatCard(
                          icon: Icons.campaign_rounded,
                          value: "$openCourses",
                          label: "กำลังเปิดรับ",
                          gradientColors: const [green, greenDark],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // รายได้รวมทั้งหมด (sum applications.priceAtSubmit)
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: fs.watchTotalRevenueAllCourses(),
                          builder: (context, snapRevenue) {
                            final revenue = snapRevenue.data ?? 0;
                            final revenueText =
                                "${revenue.toStringAsFixed(0)} ฿";

                            return _StatCard(
                              icon: Icons.attach_money_rounded,
                              value: revenueText,
                              label: "รายได้รวม",
                              gradientColors: const [
                                Color(0xFF10B981),
                                Color(0xFF065F46),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ===== หัวข้อรายการคอร์ส =====
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                  child: Row(
                    children: const [
                      Text(
                        "รายการคอร์ส",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.list_alt_rounded,
                        size: 18,
                        color: textMuted,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                if (courses.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "ยังไม่มีคอร์สในระบบ\nกด “เพิ่มคอร์ส” ด้านล่างเพื่อสร้างคอร์สใหม่",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        for (final c in courses) ...[
                          _CourseAdminTile(course: c),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            );
          },
        ),

        // FAB เพิ่มคอร์ส
        const Positioned(
          right: 24,
          bottom: 24,
          child: _AddCourseFab(),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradientColors;

  const _StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseAdminTile extends StatelessWidget {
  final Course course;
  const _CourseAdminTile({super.key, required this.course});

  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    final badgeColorBg = course.isOpen
        ? const Color(0xFF10B981).withOpacity(.12)
        : Colors.grey.withOpacity(.15);
    final badgeColorText =
        course.isOpen ? const Color(0xFF065F46) : Colors.grey.shade700;
    final badgeIcon = course.isOpen ? Icons.check_circle : Icons.lock;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColorBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              badgeIcon,
              color: badgeColorText,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // เนื้อหา + ตัวเลขสมัคร/รายได้แบบ live
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditCoursePage(
                      mode: EditCourseMode.edit,
                      existingCourse: course,
                    ),
                  ),
                );
              },
              child: StreamBuilder<int>(
                stream: fs.watchApplicantsCountForCourse(course.id),
                builder: (context, snapCount) {
                  final applicants = snapCount.data ?? 0;
                  final revenueDouble =
                      course.price * applicants.toDouble();
                  final revenueText =
                      "${revenueDouble.toStringAsFixed(0)} บาท";

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ชื่อคอร์ส
                      Text(
                        course.title.isEmpty
                            ? "(ไม่มีชื่อคอร์ส)"
                            : course.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textDark,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // รายละเอียดคอร์สย่อ
                      Text(
                        course.description.isNotEmpty
                            ? course.description
                            : "— ไม่มีรายละเอียด —",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // แถวสถิติเล็ก ๆ ใต้คอร์ส
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          _MiniStatChip(
                            icon: Icons.people_alt_rounded,
                            label: "ผู้สมัคร",
                            value: "$applicants คน",
                          ),
                          _MiniStatChip(
                            icon: Icons.payments_rounded,
                            label: "รายได้",
                            value: revenueText,
                          ),
                          _MiniStatChip(
                            icon: Icons.sell_outlined,
                            label: "ราคา/คน",
                            value: "${course.price} บาท",
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // toggle เปิด/ปิด
          Column(
            children: [
              Switch(
                value: course.isOpen,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) async {
                  await fs.setCourseOpenStatus(
                    courseId: course.id,
                    isOpen: val,
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                course.isOpen ? "เปิดรับ" : "ปิดรับ",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: course.isOpen
                      ? const Color(0xFF065F46)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black.withOpacity(.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCourseFab extends StatelessWidget {
  const _AddCourseFab({super.key});

  static const Color purple = Color(0xFF4F46E5);
  static const Color purpleDark = Color(0xFF312E81);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EditCoursePage(
              mode: EditCourseMode.create,
            ),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [purple, purpleDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: purple.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.add, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "เพิ่มคอร์ส",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
