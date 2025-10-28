import 'package:flutter/material.dart';
import '../../models/application_record.dart';
import '../../services/firestore_service.dart';
import '../chat/chat_page.dart';

class AdminApplicationDetailPage extends StatefulWidget {
  final ApplicationRecord record;
  const AdminApplicationDetailPage({
    super.key,
    required this.record,
  });

  @override
  State<AdminApplicationDetailPage> createState() =>
      _AdminApplicationDetailPageState();
}

class _AdminApplicationDetailPageState
    extends State<AdminApplicationDetailPage> {
  bool updating = false;
  String? updateMsg;

  static const Color bgPage = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color dangerRed = Color(0xFFE11D48);

  final _fs = FirestoreService();

  String _fmt(dynamic v) {
    if (v == null) return "-";
    if (v.toString().trim().isEmpty) return "-";
    return v.toString();
  }

  String _formatSubmittedAt(int ms) {
    if (ms == 0) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final nn = dt.minute.toString().padLeft(2, '0');
    return "$dd/$mm/$yy $hh:$nn";
  }

  Future<void> _approve(ApplicationRecord r) async {
    if (updating) return;
    setState(() {
      updating = true;
      updateMsg = null;
    });

    try {
      // เอาราคา snapshot (coursePrice) เป็นเงินที่จะล็อก
      final double priceToConfirm = (r.coursePrice ?? 0).toDouble();

      await _fs.approveApplicationAndSetPrice(
        appId: r.id,
        priceAtSubmit: priceToConfirm,
      );

      if (!mounted) return;
      setState(() {
        updateMsg = "อัปเดตสถานะเป็นอนุมัติแล้ว ✅";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        updateMsg = "อัปเดตสถานะไม่สำเร็จ: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        updating = false;
      });
    }
  }

  void _openChat(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          targetUserUid: uid,
          isAdminView: true,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case "pending_docs":
        bg = Colors.orange.withOpacity(.12);
        fg = Colors.orange.shade800;
        label = "ส่งใบสมัครแล้ว";
        break;
      case "waiting_verify":
        bg = Colors.blue.withOpacity(.12);
        fg = Colors.blue.shade700;
        label = "รอตรวจการชำระเงิน";
        break;
      case "approved":
        bg = Colors.green.withOpacity(.12);
        fg = Colors.green.shade700;
        label = "อนุมัติแล้ว 🎉";
        break;
      case "rejected":
        bg = Colors.red.withOpacity(.12);
        fg = Colors.red.shade700;
        label = "ไม่ผ่าน";
        break;
      default:
        bg = Colors.grey.withOpacity(.12);
        fg = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔁 ฟังเอกสารใบสมัครนี้แบบเรียลไทม์
    return StreamBuilder<ApplicationRecord?>(
      stream: _fs.watchSingleApplication(widget.record.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            backgroundColor: bgPage,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            backgroundColor: bgPage,
            body: Center(
              child: Text(
                "โหลดใบสมัครไม่สำเร็จ: ${snap.error}",
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final r = snap.data;
        if (r == null) {
          return const Scaffold(
            backgroundColor: bgPage,
            body: Center(child: Text("ไม่พบใบสมัครนี้แล้ว")),
          );
        }

        final info = r.studentInfo;

        final fullName = _fmt(info['fullName'] ?? info['name']);
        final phone = _fmt(info['phone']);
        final age = _fmt(info['age']);
        final address = _fmt(info['address']);
        final submittedAtStr = _formatSubmittedAt(r.submittedAt);

        // เงิน
        final double coursePriceSnapshot = (r.coursePrice ?? 0).toDouble();
        final double lockedRevenue = (r.priceAtSubmit ?? 0).toDouble();

        final String priceStr = (coursePriceSnapshot > 0)
            ? "${coursePriceSnapshot.toStringAsFixed(0)} บาท"
            : "—";

        final bool isApproved = r.status == "approved";
        final double earnedThisApp = isApproved ? lockedRevenue : 0.0;
        final String earnedStr = "${earnedThisApp.toStringAsFixed(0)} บาท";

        return Scaffold(
          backgroundColor: bgPage,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 60,
            centerTitle: false,
            titleSpacing: 16,
            title: Text(
              r.courseName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(.06),
              ),
            ),
          ),

          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // การ์ดสรุปคอร์ส + สถานะ + รายได้
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                r.courseName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textDark,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            _buildStatusBadge(r.status),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "ส่งเมื่อ $submittedAtStr",
                          style: const TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _miniStat(
                                label: "ราคาคอร์ส",
                                value: priceStr,
                                icon: Icons.sell_outlined,
                                iconColor: primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _miniStat(
                                label: "รายได้เคสนี้",
                                value: earnedStr,
                                icon: Icons.payments_rounded,
                                iconColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // การ์ดข้อมูลผู้สมัคร
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ข้อมูลผู้สมัคร",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _infoRow("ชื่อ-นามสกุล", fullName),
                        _infoRow("เบอร์โทร", phone),
                        _infoRow("อายุ", age),
                        _infoRow("ที่อยู่", address),
                      ],
                    ),
                  ),

                  // การ์ดสลิป / หลักฐานโอน
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "หลักฐานโอน",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (r.paymentProofUrl == null ||
                            r.paymentProofUrl!.isEmpty)
                          const Text(
                            "ยังไม่มีการแนบสลิป/หลักฐานการจ่ายเงิน",
                            style: TextStyle(
                              fontSize: 13,
                              color: textMuted,
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "อัปโหลดแล้ว",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  r.paymentProofUrl!,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  if (updateMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: updateMsg!.contains("ไม่สำเร็จ")
                            ? dangerRed.withOpacity(.08)
                            : Colors.green.withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: updateMsg!.contains("ไม่สำเร็จ")
                              ? dangerRed.withOpacity(.4)
                              : Colors.green.withOpacity(.4),
                        ),
                      ),
                      child: Text(
                        updateMsg!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: updateMsg!.contains("ไม่สำเร็จ")
                              ? dangerRed
                              : Colors.green.shade700,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ปุ่มล่าง
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryBlue.withOpacity(.4)),
                      foregroundColor: primaryBlue,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _openChat(r.uid),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text(
                      "ติดต่อผู้สมัคร",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: updating ? null : () => _approve(r),
                    icon: updating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      updating ? "กำลังอัปเดต..." : "อนุมัติแล้ว",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// widget ย่อยสำหรับสถิติเล็กๆ
Widget _miniStat({
  required String label,
  required String value,
  required IconData icon,
  required Color iconColor,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
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
