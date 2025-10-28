class ApplicationRecord {
  final String id;
  final String uid;
  final String courseId;
  final String courseName;
  final Map<String, dynamic> studentInfo;
  final String status;
  final int submittedAt;        // จาก submittedAtMs
  final String? paymentProofUrl;

  final double? coursePrice;    // ราคา snapshot ตอนสมัคร
  final double? priceAtSubmit;  // รายได้ที่ล็อกหลังอนุมัติ

  ApplicationRecord({
    required this.id,
    required this.uid,
    required this.courseId,
    required this.courseName,
    required this.studentInfo,
    required this.status,
    required this.submittedAt,
    this.paymentProofUrl,
    this.coursePrice,
    this.priceAtSubmit,
  });

  factory ApplicationRecord.fromMap(String id, Map<String, dynamic> map) {
    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int asIntMs(dynamic v) {
      if (v is int) return v;
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    return ApplicationRecord(
      id: id,
      uid: map['uid'] ?? '',
      courseId: map['courseId'] ?? '',
      courseName: map['courseName'] ?? '',
      studentInfo: Map<String, dynamic>.from(map['studentInfo'] ?? {}),
      status: map['status'] ?? '',
      submittedAt: asIntMs(map['submittedAtMs']),
      paymentProofUrl: (() {
        final raw = map['paymentProofUrl'];
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      })(),
      coursePrice: asDouble(map['coursePrice']),       // 👈 ต้องมี
      priceAtSubmit: asDouble(map['priceAtSubmit']),   // 👈 ต้องมี
    );
  }
}
