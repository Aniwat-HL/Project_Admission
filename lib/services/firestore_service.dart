import 'dart:convert'; // base64Encode
import 'package:flutter/material.dart'; // TimeOfDay
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';
import '../models/application_record.dart';
import '../models/chat_message.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ======================
  // COURSES (Student view / Public)
  // ======================

  /// นักเรียนดูเฉพาะคอร์สที่เปิดรับสมัคร
  Stream<List<Course>> watchOpenCourses() {
    return _db
        .collection('courses')
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Course.fromMap(d.id, d.data()))
            .toList());
  }

  Future<Course?> getCourse(String courseId) async {
    final doc = await _db.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return Course.fromMap(doc.id, doc.data()!);
  }

  // ======================
  // APPLICATIONS (Student submit)
  // ======================

  /// นักเรียนกดส่งใบสมัคร
  /// - status เริ่มต้น = pending_docs
  /// - เก็บ coursePrice (snapshot ราคาตอนสมัคร) เฉย ๆ
  /// - ยังไม่ใช่รายได้จริงจนกว่า admin อนุมัติ
  Future<void> submitApplication({
  required String uid,
  required String courseId,
  required String courseName,
  required Map<String, dynamic> studentInfo,
  required double coursePriceNow, // <- ราคาคอร์สตอนสมัคร
}) async {
  await _db.collection('applications').add({
    'uid': uid,
    'courseId': courseId,
    'courseName': courseName,
    'studentInfo': studentInfo,

    'status': 'pending_docs',
    'submittedAtMs': DateTime.now().millisecondsSinceEpoch,
    'paymentProofUrl': '',

    // 👇 สำคัญ ๆ
    'coursePrice': coursePriceNow,

    // ยังไม่ล็อกเป็นรายได้จนกว่าอนุมัติ
    // 'priceAtSubmit': ...
  });
}
  


  Future<void> approveApplicationAndSetPrice({
  required String appId,
  required double priceAtSubmit,
}) async {
  await _db.collection('applications').doc(appId).update({
    'status': 'approved',
    'priceAtSubmit': priceAtSubmit,
    'approvedAtMs': DateTime.now().millisecondsSinceEpoch,
  });
}


  /// นักเรียนดูใบสมัครของตัวเอง
  Stream<List<ApplicationRecord>> watchMyApplications(String uid) {
    return _db
        .collection('applications')
        .where('uid', isEqualTo: uid)
        .orderBy('submittedAtMs', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ApplicationRecord.fromMap(d.id, d.data()))
            .toList());
  }

  /// แนบหลักฐานโอน (อัปเดตเอกสารใบสมัคร)
  Future<void> attachPaymentProof({
    required String applicationId,
    required String proofUrl,
  }) async {
    await _db.collection('applications').doc(applicationId).update({
      'paymentProofUrl': proofUrl,
      'status': 'waiting_verify',
    });
  }

  // ======================
  // CHAT streams
  // ======================

  /// นักเรียนดูห้องแชทของตัวเอง
  Stream<List<ChatMessage>> watchMyChat(String myUid) {
    return _db
        .collection('chats')
        .doc(myUid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap(d.id, d.data()))
            .toList());
  }

  /// แอดมินดูห้องของนักเรียน
  Stream<List<ChatMessage>> watchChatOfUser(String userUid) {
    return _db
        .collection('chats')
        .doc(userUid)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap(d.id, d.data()))
            .toList());
  }

  // ======================
  // CHAT send: text
  // ======================

  /// นักเรียนส่งข้อความตัวอักษร
  Future<String?> sendMessageFromStudent({
    required String studentUid,
    required String studentName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return "พิมพ์ข้อความก่อนส่ง";

    try {
      final now = FieldValue.serverTimestamp();
      final chatRef = _db.collection('chats').doc(studentUid);

      await chatRef.set({
        'lastMessage': trimmed,
        'updatedAt': now,
        'role': 'student',
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderUid': studentUid,
        'senderName': studentName,
        'senderRole': 'student',
        'type': 'text',
        'text': trimmed,
        'imageBase64': null,
        'createdAt': now,
      });

      return null;
    } catch (e) {
      return "ส่งข้อความไม่สำเร็จ: $e";
    }
  }

  /// แอดมินส่งข้อความตัวอักษรไปยังห้องของนักเรียน
  Future<String?> sendMessageFromAdmin({
    required String targetUserUid,
    required String adminUid,
    required String adminName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return "พิมพ์ข้อความก่อนส่ง";

    try {
      final now = FieldValue.serverTimestamp();
      final chatRef = _db.collection('chats').doc(targetUserUid);

      await chatRef.set({
        'lastMessage': trimmed,
        'updatedAt': now,
        'role': 'student',
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderUid': adminUid,
        'senderName': adminName,
        'senderRole': 'admin',
        'type': 'text',
        'text': trimmed,
        'imageBase64': null,
        'createdAt': now,
      });

      return null;
    } catch (e) {
      return "ส่งข้อความไม่สำเร็จ (admin): $e";
    }
  }

  // ======================
  // CHAT send: image (เช่นสลิป)
  // ======================

  Future<String?> sendImageFromStudent({
    required String studentUid,
    required String studentName,
    required List<int> imageBytes,
  }) async {
    if (imageBytes.isEmpty) return "เลือกรูปไม่สำเร็จ";

    try {
      final now = FieldValue.serverTimestamp();
      final chatRef = _db.collection('chats').doc(studentUid);

      final b64 = base64Encode(imageBytes);

      await chatRef.set({
        'lastMessage': '[ส่งสลิปเป็นรูปภาพ]',
        'updatedAt': now,
        'role': 'student',
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderUid': studentUid,
        'senderName': studentName,
        'senderRole': 'student',
        'type': 'image',
        'text': null,
        'imageBase64': b64,
        'createdAt': now,
      });

      return null;
    } catch (e) {
      return "ส่งรูปไม่สำเร็จ: $e";
    }
  }

  // ======================
  // CHAT DELETE HELPERS
  // ======================

  Future<void> deleteSingleMessage({
    required String roomUserUid,
    required String messageId,
  }) async {
    final roomRef = _db.collection('chats').doc(roomUserUid);

    await roomRef
        .collection('messages')
        .doc(messageId)
        .delete();

    final latestSnap = await roomRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (latestSnap.docs.isEmpty) {
      await roomRef.set({
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final lastData = latestSnap.docs.first.data();
      await roomRef.set({
        'lastMessage': lastData['text'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteWholeChatRoom({required String userUid}) async {
    final roomRef = _db.collection('chats').doc(userUid);

    final msgs = await roomRef.collection('messages').get();
    final batch = _db.batch();
    for (final m in msgs.docs) {
      batch.delete(m.reference);
    }
    await batch.commit();

    await roomRef.delete();
  }

  // ======================
  // ADMIN inbox list
  // ======================

  Stream<List<Map<String, dynamic>>> watchAllChatRoomsForAdmin() async* {
    final snapStream = _db
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .snapshots();

    await for (final snap in snapStream) {
      final result = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final userUid = doc.id;

        final profileSnap =
            await _db.collection('users').doc(userUid).get();
        final displayName =
            profileSnap.data()?['displayName'] ?? userUid;

        result.add({
          'userUid': userUid,
          'displayName': displayName,
          'lastMessage': data['lastMessage'] ?? '',
          'updatedAt': data['updatedAt'],
        });
      }

      yield result;
    }
  }

  // ======================
  // ADMIN: COURSES MANAGEMENT
  // ======================

  Stream<List<Course>> watchAllCoursesForAdmin() {
    return _db
        .collection('courses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Course.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> createCourse({
    required String title,
    required String description,
    required String schedule,
    required double price,
    required bool isOpen,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final now = FieldValue.serverTimestamp();

    final startTimeStr =
        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    final endTimeStr =
        "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";

    await _db.collection('courses').add({
      'title': title,
      'description': description,
      'schedule': schedule,
      'price': price,
      'isOpen': isOpen,

      'startDate': Timestamp.fromDate(
        DateTime(startDate.year, startDate.month, startDate.day),
      ),
      'endDate': Timestamp.fromDate(
        DateTime(endDate.year, endDate.month, endDate.day),
      ),
      'startTime': startTimeStr,
      'endTime': endTimeStr,

      'name': title,
      'open': isOpen,
      'thumbnailUrl': null,

      'createdAt': now,
    });
  }

  Future<void> updateCourse({
    required String courseId,
    required String title,
    required String description,
    required String schedule,
    required double price,
    required bool isOpen,
    required DateTime startDate,
    required DateTime endDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final startTimeStr =
        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    final endTimeStr =
        "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";

    await _db.collection('courses').doc(courseId).update({
      'title': title,
      'description': description,
      'schedule': schedule,
      'price': price,
      'isOpen': isOpen,

      'startDate': Timestamp.fromDate(
        DateTime(startDate.year, startDate.month, startDate.day),
      ),
      'endDate': Timestamp.fromDate(
        DateTime(endDate.year, endDate.month, endDate.day),
      ),
      'startTime': startTimeStr,
      'endTime': endTimeStr,

      'name': title,
      'open': isOpen,
    });
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.collection('courses').doc(courseId).delete();
  }

  Future<void> setCourseOpenStatus({
    required String courseId,
    required bool isOpen,
  }) async {
    await _db.collection('courses').doc(courseId).update({
      'isOpen': isOpen,
      'open': isOpen,
    });
  }

  // ======================
  // ADMIN: APPLICATIONS
  // ======================

  Stream<List<ApplicationRecord>> watchAllApplicationsForAdmin() {
    return _db
        .collection('applications')
        .orderBy('submittedAtMs', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ApplicationRecord.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<ApplicationRecord>> watchAllApplicationsForAdminFiltered({
    String? courseIdFilter,
  }) {
    Query<Map<String, dynamic>> q = _db
        .collection('applications')
        .orderBy('submittedAtMs', descending: true);

    if (courseIdFilter != null && courseIdFilter.isNotEmpty) {
      q = q.where('courseId', isEqualTo: courseIdFilter);
    }

    return q.snapshots().map((snap) => snap.docs
        .map((d) => ApplicationRecord.fromMap(d.id, d.data()))
        .toList());
  }

  Future<void> updateApplicationStatus({
    required String appId,
    required String newStatus,
  }) async {
    await _db.collection('applications').doc(appId).update({
      'status': newStatus,
    });
  }

  Future<void> deleteApplication(String appId) async {
    await _db.collection('applications').doc(appId).delete();
  }

  // ======================
  // USER PROFILE HELPERS / STATS
  // ======================

  Future<String> getUserDisplayName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return uid;
      final data = doc.data();
      final name = data?['displayName'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
      return uid;
    } catch (_) {
      return uid;
    }
  }

  Stream<int> watchTotalUsers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<int> watchApplicantsCountForCourse(String courseId) {
    return _db
        .collection('applications')
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// ยอดรวมรายได้ทั้งหมด (sum priceAtSubmit เฉพาะใบสมัครที่อนุมัติแล้ว)
  Stream<double> watchTotalRevenueAllCourses() {
    return _db
        .collection('applications')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) {
      double sum = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final num? p = data['priceAtSubmit'];
        if (p != null) {
          sum += p.toDouble();
        }
      }
      return sum;
    });
  }

// ใน class FirestoreService (ข้างในไฟล์ firestore_service.dart)
// วางไว้ตรงไหนก็ได้ในคลาส FirestoreService เช่นใต้ approveApplicationAndSetPrice()

Stream<ApplicationRecord?> watchSingleApplication(String appId) {
  return _db
      .collection('applications')
      .doc(appId)
      .snapshots()
      .map((docSnap) {
    if (!docSnap.exists) {
      return null;
    }
    final data = docSnap.data();
    if (data == null) return null;
    return ApplicationRecord.fromMap(docSnap.id, data);
  });
}

}
