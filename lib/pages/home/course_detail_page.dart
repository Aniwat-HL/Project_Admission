import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/course.dart';
import '../application/application_form_page.dart';

class CourseDetailPage extends StatefulWidget {
  final String courseId;
  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final _fs = FirestoreService();

  Course? course;
  bool loading = true;
  String? errorMsg;

  // โทนสีหลัก แบบเดียวกับหน้าแรก (ฟ้าอ่อน / น้ำเงิน)
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color pageBg = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _fs.getCourse(widget.courseId);
      setState(() {
        course = c;
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = "$e";
        loading = false;
      });
    }
  }

  void _handleApplyPressed() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      // ยังไม่ล็อกอิน
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("กรุณาเข้าสู่ระบบก่อนสมัคร"),
        ),
      );
      return;
    }

    final c = course;
    if (c == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationFormPage(course: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = course;
    final titleText = c == null
        ? ""
        : (c.title.isNotEmpty ? c.title : "(ไม่มีชื่อคอร์ส)");

    return Scaffold(
      backgroundColor: pageBg,

      // เราจะจัด layout เองแทน AppBar ปกติ
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMsg != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "เกิดข้อผิดพลาด:\n$errorMsg",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : c == null
                    ? const Center(
                        child: Text("ไม่พบคอร์สนี้"),
                      )
                    : CustomScrollView(
                        slivers: [
                          // ---------- HEADER (gradient + back button + title) ----------
                          SliverToBoxAdapter(
                            child: _HeaderBar(
                              title: titleText,
                              subtitle: "รายละเอียดคอร์สและการสมัคร",
                              onBack: () => Navigator.pop(context),
                            ),
                          ),

                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),

                          // ---------- การ์ดข้อมูลคอร์ส ----------
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _CourseInfoCard(course: c),
                            ),
                          ),

                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),

                          // ---------- การ์ดรายละเอียดคอร์ส ----------
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: _DescriptionCard(course: c),
                            ),
                          ),

                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),

                          // ---------- ปุ่มสมัคร ----------
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryBlue,
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size.fromHeight(52), // สูงขึ้น
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 3,
                                    ),
                                    onPressed: _handleApplyPressed,
                                    icon: const Icon(Icons.send),
                                    label: const Text(
                                      "สมัครคอร์สนี้",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "หลังสมัคร คุณจะสามารถแนบสลิปโอนเงิน และติดตามสถานะการอนุมัติได้ในแท็บ “สถานะ”",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// HEADER BAR (เหมือนหน้าแรกสไตล์การ์ดฟ้าอ่อน มุมโค้ง + back)
// ------------------------------------------------------------------
class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  static const Color primaryBlue = Color(0xFF2563EB);

  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // gradient คล้าย header card หน้าแรก
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEAF4FF),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x332563EB), // ฟ้าจางๆ
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ปุ่ม back
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ชื่อคอร์ส + sub
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    );
  }
}

// ------------------------------------------------------------------
// การ์ดข้อมูลหลักคอร์ส (ราคา / รอบเรียน / สถานะเปิดรับสมัคร)
// ------------------------------------------------------------------
class _CourseInfoCard extends StatelessWidget {
  final Course course;
  const _CourseInfoCard({required this.course});

  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    // ป้ายสถานะเปิด-ปิดรับสมัคร
    final isOpen = course.isOpen;
    final badgeColor =
        isOpen ? const Color(0xFFE8FEE6) : const Color(0xFFFFF4E5);
    final badgeTextColor =
        isOpen ? const Color(0xFF15803D) : const Color(0xFF92400E);
    final badgeIcon = isOpen ? Icons.check_circle : Icons.lock_clock;
    final badgeText = isOpen ? "เปิดรับสมัคร" : "ปิดรับสมัคร";

    final priceText = course.price > 0
        ? "ค่าเรียน ${course.price.toStringAsFixed(0)} บาท"
        : "ค่าเรียน: สอบถามเพิ่มเติม";

    // เวลา / schedule
    final scheduleText = course.schedule.isNotEmpty
        ? course.schedule
        : "กรุณาสอบถามรอบเรียน";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // บรรทัดแรก: badge + ราคา
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
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
                  mainAxisSize: MainAxisSize.min,
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

              const Spacer(),

              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                  height: 1.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // schedule
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scheduleText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// การ์ด "รายละเอียดคอร์ส"
// ------------------------------------------------------------------
class _DescriptionCard extends StatelessWidget {
  final Course course;
  const _DescriptionCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final desc = course.description.isNotEmpty
        ? course.description
        : "ไม่มีรายละเอียดเพิ่มเติม";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "รายละเอียดคอร์ส",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
