import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/application_record.dart';
import '../../models/course.dart';
import 'admin_application_detail_page.dart';

class AdminApplicationsPage extends StatefulWidget {
  const AdminApplicationsPage({super.key});

  @override
  State<AdminApplicationsPage> createState() => _AdminApplicationsPageState();
}

class _AdminApplicationsPageState extends State<AdminApplicationsPage> {
  final _fs = FirestoreService();

  String? _selectedCourseId; // null = ทั้งหมด
  List<Course> _courses = [];
  bool _loadingCourses = true;

  static const bgPage = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const cardBorder = Color(0x14000000); // black 8%
  static const primaryBlue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    // listen รายชื่อคอร์สให้ dropdown
    _fs.watchAllCoursesForAdmin().listen((cs) {
      if (!mounted) return;
      setState(() {
        _courses = cs;
        _loadingCourses = false;
      });
    });
  }

  // ---------- helpers ----------

  // map status -> สี + label
  Color _statusColorBg(String status) {
    switch (status) {
      case "pending_docs":
        return const Color(0xFFFFF7E6); // อ่อนส้ม
      case "waiting_verify":
        return const Color(0xFFEFF6FF); // อ่อนฟ้า
      case "approved":
        return const Color(0xFFE8FEE6); // อ่อนเขียว
      case "rejected":
        return const Color(0xFFFFEBEE); // อ่อนแดง
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusColorFg(String status) {
    switch (status) {
      case "pending_docs":
        return const Color(0xFF92400E); // น้ำตาลส้ม
      case "waiting_verify":
        return const Color(0xFF1D4ED8); // น้ำเงิน
      case "approved":
        return const Color(0xFF15803D); // เขียว
      case "rejected":
        return const Color(0xFFB91C1C); // แดงเข้ม
      default:
        return Colors.grey.shade700;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "pending_docs":
        return "ส่งใบสมัครแล้ว";
      case "waiting_verify":
        return "รอตรวจ";
      case "approved":
        return "อนุมัติแล้ว";
      case "rejected":
        return "ไม่ผ่าน";
      default:
        return status;
    }
  }

  String _formatDate(int ms) {
    if (ms == 0) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final nn = dt.minute.toString().padLeft(2, '0');
    return "$dd/$mm/$yy $hh:$nn";
  }

  Future<void> _confirmDeleteApp(ApplicationRecord app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "ลบใบสมัครนี้?",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "ชื่อ: ${app.studentInfo['fullName'] ?? '-'}\n"
          "คอร์ส: ${app.courseName}\n\n"
          "การลบจะไม่สามารถกู้คืนได้",
          style: const TextStyle(height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text(
              "ลบเลย",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _fs.deleteApplication(app.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ลบใบสมัครเรียบร้อย")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ลบไม่สำเร็จ: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsStream = _fs.watchAllApplicationsForAdminFiltered(
      courseIdFilter: _selectedCourseId,
    );

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          "ผู้สมัครทั้งหมด",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(.06),
          ),
        ),
      ),
      body: Column(
        children: [
          // ---------- FILTER CARD ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ไอคอนกรอง
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // dropdown + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "กรองตามคอร์ส",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _loadingCourses
                            ? const SizedBox(
                                height: 48,
                                child: Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _buildCourseDropdown(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ---------- LIST CONTENT ----------
          Expanded(
            child: StreamBuilder<List<ApplicationRecord>>(
              stream: appsStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

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

                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.grey.shade400,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "ยังไม่มีผู้สมัครในคอร์สนี้",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 24), // spacing ขอบ
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final app = list[i];
                    final fullName =
                        (app.studentInfo['fullName'] ?? '') as String? ?? '';
                    final submittedAtText = _formatDate(app.submittedAt);

                    final bg = _statusColorBg(app.status);
                    final fg = _statusColorFg(app.status);
                    final label = _statusLabel(app.status);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminApplicationDetailPage(
                                record: app,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // avatar
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryBlue.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    (fullName.isNotEmpty
                                            ? fullName[0].toUpperCase()
                                            : 'U')
                                        .toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: primaryBlue,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // main info block
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // top row: name + status pill
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            fullName.isEmpty
                                                ? "(ไม่มีชื่อ)"
                                                : fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: textDark,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: fg.withOpacity(.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                size: 8,
                                                color: fg,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: fg,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    // course name
                                    Text(
                                      app.courseName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textDark,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // submitted at
                                    Text(
                                      "ยื่นเมื่อ $submittedAtText",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: textMuted,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // delete button (icon chip)
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  _confirmDeleteApp(app);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseDropdown() {
    // "ทั้งหมด" + รายชื่อคอร์ส
    final items = <DropdownMenuItem<String?>>[];

    items.add(
      const DropdownMenuItem<String?>(
        value: null,
        child: Text(
          "ทั้งหมด",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ),
    );

    items.addAll(
      _courses.map((c) {
        return DropdownMenuItem<String?>(
          value: c.id,
          child: Text(
            c.title.isNotEmpty ? c.title : c.rawName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        );
      }),
    );

    return DropdownButtonFormField<String?>(
      value: _selectedCourseId,
      items: items,
      onChanged: (val) {
        setState(() {
          _selectedCourseId = val;
        });
      },
      icon: const Icon(Icons.expand_more_rounded, size: 20),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textDark,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(.1),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
