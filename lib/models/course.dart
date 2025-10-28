import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ สำคัญ: เพื่อใช้ Timestamp

class Course {
  final String id;

  // ฟิลด์หลักที่ใช้โชว์ใน UI นักเรียน
  final String title;        // ชื่อคอร์ส
  final String description;  // รายละเอียดคอร์ส
  final String schedule;     // สรุปเวลาเรียนสำหรับโชว์ เช่น "วันที่ 1/11/2025 เวลา 09:00 - 12:00"
  final double price;        // ราคา
  final bool isOpen;         // เปิดรับสมัคร?

  // ฟิลด์โครงสร้างใหม่ (เลือกผ่าน date/time picker)
  final DateTime? startDate; // วันเริ่มคอร์ส
  final DateTime? endDate;   // วันจบคอร์ส
  final String? startTime;   // เวลาเริ่ม "HH:mm"
  final String? endTime;     // เวลาจบ "HH:mm"

  // ฟิลด์สำรอง/เก่า (กันโค้ดเก่าไม่พัง)
  final String? thumbnailUrl;
  final String rawName;      // เดิมเก็บใน 'name'
  final String rawTitle;     // เดิมเก็บใน 'title'

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.schedule,
    required this.price,
    required this.isOpen,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.thumbnailUrl,
    required this.rawName,
    required this.rawTitle,
  });

  factory Course.fromMap(String id, Map<String, dynamic> data) {
    // -----------------------------
    // 1) ชื่อคอร์ส
    // -----------------------------
    // บาง doc เก็บเป็น 'title', บาง doc เก็บเป็น 'name'
    final String t = (data['title'] ?? data['name'] ?? '') as String;
    final String n = (data['name'] ?? data['title'] ?? '') as String;

    // -----------------------------
    // 2) รายละเอียด
    // -----------------------------
    final String description = (data['description'] ?? '') as String;

    // -----------------------------
    // 3) schedule string (แบบพร้อมโชว์)
    // -----------------------------
    final String schedule = (data['schedule'] ?? '') as String;

    // -----------------------------
    // 4) ราคา -> double ปลอดภัย
    // -----------------------------
    double parsePrice(dynamic p) {
      if (p is int) return p.toDouble();
      if (p is double) return p;
      if (p is String) {
        final parsed = double.tryParse(p);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    final double price = parsePrice(data['price']);

    // -----------------------------
    // 5) isOpen (เปิดรับสมัคร?)
    // -----------------------------
    final bool openVal = (() {
      final v = data['isOpen'] ?? data['open'] ?? true;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      return true;
    })();

    // -----------------------------
    // 6) วันเริ่ม/วันจบ (startDate/endDate)
    // Firestore อาจเก็บเป็น Timestamp หรือ millis int
    // -----------------------------
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;

      // เคส Firestore Timestamp
      if (v is Timestamp) {
        return v.toDate();
      }

      // เคส millisSinceEpoch (int)
      if (v is int) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }

      return null;
    }

    final DateTime? startDate = parseDate(data['startDate']);
    final DateTime? endDate = parseDate(data['endDate']);

    // -----------------------------
    // 7) เวลาเริ่ม/เวลาจบ (string "HH:mm")
    // -----------------------------
    final String? startTimeRaw = (data['startTime'] ?? '') as String?;
    final String? endTimeRaw = (data['endTime'] ?? '') as String?;

    final String? startTime =
        (startTimeRaw != null && startTimeRaw.isNotEmpty) ? startTimeRaw : null;
    final String? endTime =
        (endTimeRaw != null && endTimeRaw.isNotEmpty) ? endTimeRaw : null;

    // -----------------------------
    // 8) thumbnailUrl เดิม (เราไม่โชว์รูปแล้ว แต่เผื่อข้อมูลเก่า)
    // -----------------------------
    final String? thumbnailUrl = data['thumbnailUrl'] as String?;

    return Course(
        id: id,
        title: t,
        description: description,
        schedule: schedule,
        price: price,
        isOpen: openVal,
        startDate: startDate,
        endDate: endDate,
        startTime: startTime,
        endTime: endTime,
        thumbnailUrl: thumbnailUrl,
        rawName: n,
        rawTitle: t);
  }

  /// ถ้าอยากส่งกลับขึ้น Firestore เอง (ปกติเราใช้ FirestoreService.createCourse()/updateCourse())
  Map<String, dynamic> toMapForSave() {
    return {
      // ฟิลด์หลัก
      'title': title,
      'name': title,
      'description': description,
      'schedule': schedule,
      'price': price,
      'isOpen': isOpen,
      'open': isOpen,

      // วัน/เวลาแบบเครื่องอ่าน
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'startTime': startTime,
      'endTime': endTime,

      // ของเก่า
      'thumbnailUrl': thumbnailUrl,
    };
  }
}
