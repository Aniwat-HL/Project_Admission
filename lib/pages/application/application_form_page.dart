import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/course.dart';
import '../../services/firestore_service.dart';
import '../application/my_application_status_page.dart';

class ApplicationFormPage extends StatefulWidget {
  final Course course;

  const ApplicationFormPage({
    super.key,
    required this.course,
  });

  @override
  State<ApplicationFormPage> createState() => _ApplicationFormPageState();
}

class _ApplicationFormPageState extends State<ApplicationFormPage> {
  // --- Controllers ---
  final _fullNameCtl = TextEditingController(); // readOnly
  final _nickNameCtl = TextEditingController();
  final _dobCtl = TextEditingController(); // shown as dd/MM/yyyy, readOnly
  final _ageCtl = TextEditingController(); // auto-calculated, readOnly
  final _gradeCtl = TextEditingController();
  final _schoolCtl = TextEditingController();

  final _phoneCtl = TextEditingController();
  final _contactCtl = TextEditingController(); // line / fb / email
  final _addressCtl = TextEditingController();
  final _reasonCtl = TextEditingController();

  final _parentNameCtl = TextEditingController();
  final _parentRelationCtl = TextEditingController();
  final _parentPhoneCtl = TextEditingController();
  final _parentContactCtl = TextEditingController();

  final _noteCtl = TextEditingController();

  final _fs = FirestoreService();

  bool sending = false;
  String? infoMsg;

  // validate เบอร์โทร
  String? _phoneError;
  String? _parentPhoneError;

  // วันเกิดจริง
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  // เติมข้อมูลจาก user โปรไฟล์
  Future<void> _prefillFromProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (data != null) {
        final displayName = (data['displayName'] ?? '') as String;
        final phone = (data['phone'] ?? '') as String;

        setState(() {
          _fullNameCtl.text = displayName;
          _phoneCtl.text = phone;
        });
      } else {
        setState(() {
          _fullNameCtl.text = user.displayName ?? '';
        });
      }
    } catch (_) {
      setState(() {
        _fullNameCtl.text = user.displayName ?? '';
      });
    }

    _validatePhone();
  }

  // ----- DOB picker -----
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 30, 1, 1);
    final lastDate = DateTime(now.year - 5, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 15, now.month, now.day),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "เลือกวันเกิด",
      confirmText: "ยืนยัน",
      cancelText: "ยกเลิก",
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtl.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
        _ageCtl.text = _calculateAge(picked).toString();
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthdayThisYear = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthdayThisYear) {
      age -= 1;
    }
    return age;
  }

  // validate เบอร์
  void _validatePhone() {
    final value = _phoneCtl.text.trim();
    if (value.isEmpty) {
      _phoneError = "กรุณากรอกเบอร์โทร";
    } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      _phoneError = "กรุณากรอกเฉพาะตัวเลข";
    } else if (value.length != 10) {
      _phoneError = "หมายเลขต้องมี 10 หลัก";
    } else {
      _phoneError = null;
    }
    setState(() {});
  }

  void _validateParentPhone() {
    final value = _parentPhoneCtl.text.trim();
    if (value.isEmpty) {
      _parentPhoneError = "กรุณากรอกเบอร์ผู้ปกครอง";
    } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      _parentPhoneError = "กรุณากรอกเฉพาะตัวเลข";
    } else if (value.length != 10) {
      _parentPhoneError = "หมายเลขต้องมี 10 หลัก";
    } else {
      _parentPhoneError = null;
    }
    setState(() {});
  }

  // ข้อมูลครบไหม + เบอร์ ok + ไม่กำลังส่ง
  bool _canSubmit() {
    final reqFilled = _fullNameCtl.text.trim().isNotEmpty &&
        _nickNameCtl.text.trim().isNotEmpty &&
        _selectedDob != null &&
        _ageCtl.text.trim().isNotEmpty &&
        _gradeCtl.text.trim().isNotEmpty &&
        _schoolCtl.text.trim().isNotEmpty &&
        _phoneCtl.text.trim().isNotEmpty &&
        _contactCtl.text.trim().isNotEmpty &&
        _addressCtl.text.trim().isNotEmpty &&
        _parentNameCtl.text.trim().isNotEmpty &&
        _parentRelationCtl.text.trim().isNotEmpty &&
        _parentPhoneCtl.text.trim().isNotEmpty;

    final phoneOk = _phoneError == null && _parentPhoneError == null;

    return reqFilled && phoneOk && !sending;
  }

  // ----- ส่งข้อความแจ้งแอดมินในห้องแชทของเด็ก -----
  Future<void> _sendApplicationToAdminChat({
    required String uid,
  }) async {
    final studentName = _fullNameCtl.text.trim();

    final textForAdmin = '''
📌 มีการสมัครคอร์สใหม่

คอร์ส: ${widget.course.title}
ราคา ณ ตอนสมัคร: ${widget.course.price.toStringAsFixed(0)} บาท

👤 ผู้สมัคร
• ชื่อ-นามสกุล: ${_fullNameCtl.text.trim()}
• ชื่อเล่น: ${_nickNameCtl.text.trim()}
• วันเกิด: ${_dobCtl.text.trim()} (อายุ ${_ageCtl.text.trim()})
• ชั้นปี: ${_gradeCtl.text.trim()}
• โรงเรียน: ${_schoolCtl.text.trim()}

📞 การติดต่อ
• เบอร์: ${_phoneCtl.text.trim()}
• ช่องทาง: ${_contactCtl.text.trim()}
• ที่อยู่: ${_addressCtl.text.trim()}

🎯 เหตุผลที่อยากเรียน
${_reasonCtl.text.trim().isEmpty ? "-" : _reasonCtl.text.trim()}

👨‍👩‍👧 ผู้ปกครอง
• ชื่อ: ${_parentNameCtl.text.trim()} (${_parentRelationCtl.text.trim()})
• เบอร์: ${_parentPhoneCtl.text.trim()}
• ช่องทาง: ${_parentContactCtl.text.trim().isEmpty ? "-" : _parentContactCtl.text.trim()}

📝 หมายเหตุเพิ่มเติม
${_noteCtl.text.trim().isEmpty ? "-" : _noteCtl.text.trim()}
''';

    // ส่งข้อความหลัก (รายละเอียดใบสมัคร)
    await _fs.sendMessageFromStudent(
      studentUid: uid,
      studentName: studentName.isEmpty ? "นักเรียน" : studentName,
      text: textForAdmin,
    );

    // ส่ง follow-up แจ้งสั้น ๆ ให้ admin ชัวร์ ๆ
    await _fs.sendMessageFromStudent(
      studentUid: uid,
      studentName: studentName.isEmpty ? "นักเรียน" : studentName,
      text:
          "📎 ผู้สมัครได้ส่งใบสมัครคอร์ส \"${widget.course.title}\" แล้ว โปรดตรวจสอบใน Dashboard ✅",
    );
  }

  // ----- submit หลัก -----
  Future<void> _handleSubmit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        infoMsg = "กรุณาเข้าสู่ระบบก่อน";
      });
      return;
    }

    if (!_canSubmit()) {
      setState(() {
        infoMsg = "กรุณากรอกข้อมูลที่จำเป็นให้ครบและถูกต้อง";
      });
      return;
    }

    setState(() {
      sending = true;
      infoMsg = null;
    });

    try {
      // 1) บันทึกใบสมัครลง Firestore
      await _fs.submitApplication(
        uid: user.uid,
        courseId: widget.course.id,
        courseName: widget.course.title,
        coursePriceNow: widget.course.price, // 👈 snapshot ราคา
        studentInfo: {
          'fullName': _fullNameCtl.text.trim(),
          'nickName': _nickNameCtl.text.trim(),
          'dob': _dobCtl.text.trim(),
          'age': _ageCtl.text.trim(),
          'grade': _gradeCtl.text.trim(),
          'school': _schoolCtl.text.trim(),
          'phone': _phoneCtl.text.trim(),
          'contact': _contactCtl.text.trim(),
          'address': _addressCtl.text.trim(),
          'reason': _reasonCtl.text.trim(),
          'parentName': _parentNameCtl.text.trim(),
          'parentRelation': _parentRelationCtl.text.trim(),
          'parentPhone': _parentPhoneCtl.text.trim(),
          'parentContact': _parentContactCtl.text.trim(),
          'note': _noteCtl.text.trim(),
        },
      );

      // 2) ส่งแจ้งในแชทให้แอดมินเห็นทันที
      await _sendApplicationToAdminChat(uid: user.uid);

      if (!mounted) return;

      // 3) ไปหน้า "สถานะใบสมัครของฉัน"
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MyApplicationStatusPage()),
        (route) => route.isFirst,
      );
    } catch (e) {
      setState(() {
        infoMsg = "เกิดข้อผิดพลาด: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // ---------- widget helper ----------
  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool requiredMark = false,
    String? placeholder,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                requiredMark ? "$label *" : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onTap: onTap,
          onChanged: (_) {
            // validate ระหว่างพิมพ์
            if (controller == _phoneCtl) _validatePhone();
            if (controller == _parentPhoneCtl) _validateParentPhone();
            setState(() {}); // refresh ปุ่ม submit
          },
          decoration: InputDecoration(
            hintText: placeholder,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            errorText: errorText,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _nickNameCtl.dispose();
    _dobCtl.dispose();
    _ageCtl.dispose();
    _gradeCtl.dispose();
    _schoolCtl.dispose();
    _phoneCtl.dispose();
    _contactCtl.dispose();
    _addressCtl.dispose();
    _reasonCtl.dispose();
    _parentNameCtl.dispose();
    _parentRelationCtl.dispose();
    _parentPhoneCtl.dispose();
    _parentContactCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "สมัคร ${c.title}",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------- ข้อมูลผู้สมัคร --------
                const Text(
                  "ข้อมูลผู้สมัคร",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ชื่อ–นามสกุล (Full Name)",
                  controller: _fullNameCtl,
                  requiredMark: true,
                  readOnly: true, // 🔒 ห้ามแก้
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ชื่อเล่น (Nickname)",
                  controller: _nickNameCtl,
                  requiredMark: true,
                  placeholder: "เช่น โบ๊ท / น้ำ",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "วัน/เดือน/ปีเกิด (Date of Birth)",
                  controller: _dobCtl,
                  requiredMark: true,
                  readOnly: true,
                  placeholder: "เช่น 12/08/2007",
                  onTap: _pickDob,
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "อายุ (Age)",
                  controller: _ageCtl,
                  requiredMark: true,
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ชั้นปีที่กำลังศึกษา (Current Grade)",
                  controller: _gradeCtl,
                  requiredMark: true,
                  placeholder: "เช่น ม.5 / ปี 2 / etc.",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "โรงเรียน (School)",
                  controller: _schoolCtl,
                  requiredMark: true,
                ),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 24),

                // -------- การติดต่อผู้สมัคร --------
                const Text(
                  "การติดต่อผู้สมัคร",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "เบอร์โทรศัพท์ (Phone Number)",
                  controller: _phoneCtl,
                  requiredMark: true,
                  keyboardType: TextInputType.phone,
                  errorText: _phoneError,
                  placeholder: "เช่น 0812345678",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "Line ID / Facebook / Email (Contact Information)",
                  controller: _contactCtl,
                  requiredMark: true,
                  placeholder: "เช่น line: myline123",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ที่อยู่ปัจจุบัน (Current Address)",
                  controller: _addressCtl,
                  requiredMark: true,
                  maxLines: 2,
                  placeholder: "บ้านเลขที่ / เขต / จังหวัด",
                ),
                const SizedBox(height: 16),

                _textField(
                  label:
                      "เหตุผลที่เลือกเรียนคอร์สนี้ (Reason for Choosing This Course)",
                  controller: _reasonCtl,
                  maxLines: 3,
                  placeholder:
                      "อะไรทำให้สนใจคอร์สนี้ / อยากพัฒนาทักษะด้านไหน / เป้าหมายคืออะไร",
                ),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 24),

                // -------- ผู้ปกครอง --------
                const Text(
                  "ข้อมูลผู้ปกครอง",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ชื่อ–นามสกุลผู้ปกครอง (Parent / Guardian Full Name)",
                  controller: _parentNameCtl,
                  requiredMark: true,
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "ความสัมพันธ์กับผู้สมัคร (Relationship to Applicant)",
                  controller: _parentRelationCtl,
                  requiredMark: true,
                  placeholder: "เช่น แม่ / พ่อ / ผู้ปกครอง / ญาติ",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "เบอร์โทรศัพท์ผู้ปกครอง (Parent’s Phone Number)",
                  controller: _parentPhoneCtl,
                  requiredMark: true,
                  keyboardType: TextInputType.phone,
                  errorText: _parentPhoneError,
                  placeholder: "เช่น 0812345678",
                ),
                const SizedBox(height: 16),

                _textField(
                  label: "อีเมล / Line ID ผู้ปกครอง (Parent’s Email / Line ID)",
                  controller: _parentContactCtl,
                  placeholder: "ช่องทางติดต่อผู้ปกครอง",
                ),
                const SizedBox(height: 24),

                const Divider(),
                const SizedBox(height: 24),

                // -------- หมายเหตุ --------
                _textField(
                  label:
                      "หมายเหตุ / ข้อความเพิ่มเติม (Additional Notes / Comments)",
                  controller: _noteCtl,
                  maxLines: 3,
                  placeholder:
                      "แพ้อาหาร / เวลาที่สะดวกเรียน / รายละเอียดอื่น ๆ ที่อยากแจ้งทีมสอน",
                ),

                if (infoMsg != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    infoMsg!,
                    style: TextStyle(
                      fontSize: 13,
                      color: infoMsg!.startsWith("เกิดข้อผิดพลาด")
                          ? Colors.red
                          : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _canSubmit() ? _handleSubmit : null,
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      sending ? "กำลังส่ง..." : "ส่งใบสมัคร",
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
