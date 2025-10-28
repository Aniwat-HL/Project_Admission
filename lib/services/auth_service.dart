import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ตัวแทนข้อมูลผู้ใช้ที่เราเก็บใน Firestore
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String phone;
  final String role; // 'student' หรือ 'admin'
  final int? createdAtMillis; // เก็บเป็น ms since epoch ถ้ามี

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.role,
    this.createdAtMillis,
  });

  /// ปลอดภัยขึ้น: ถ้าบางฟิลด์ไม่มีใน Firestore ก็ fallback เป็นค่าว่าง
  factory AppUser.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return AppUser(
      uid: uid,
      email: (data['email'] ?? '') as String,
      displayName: (data['displayName'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      role: (data['role'] ?? 'student') as String,
      createdAtMillis: _extractCreatedAtMillis(data['createdAt']),
    );
  }

  static int? _extractCreatedAtMillis(dynamic raw) {
    // เราเผื่อ 3 เคส:
    // 1) เก็บเป็น int millis
    // 2) เก็บเป็น Timestamp (serverTimestamp)
    // 3) ไม่มีค่า
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is Timestamp) {
      return raw.millisecondsSinceEpoch;
    }
    return null;
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// สร้างเอกสาร /users/{uid} ถ้ายังไม่มี
  /// - เรียกใช้หลัง Google Sign-In สำเร็จ
  /// - หรือหลัง register() ถ้าต้องการความชัวร์
  Future<void> ensureUserDocumentExists({
    required User firebaseUser,
  }) async {
    final docRef = _db.collection('users').doc(firebaseUser.uid);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      // มีข้อมูลแล้ว ไม่ต้องทำอะไร
      return;
    }

    final email = firebaseUser.email ?? '';
    // email admin พิเศษ → role = admin
    final String assignedRole =
        (email.toLowerCase() == 'admin@admin.com') ? 'admin' : 'student';

    await docRef.set({
      'uid': firebaseUser.uid,
      'email': email,
      'displayName': firebaseUser.displayName ?? 'ผู้ใช้ใหม่',
      'phone': '',
      'role': assignedRole,
      'createdAt': FieldValue
          .serverTimestamp(), // ให้ server เป็นคนใส่ timestamp
    });
  }

  /// สมัครสมาชิกด้วยอีเมล/รหัสผ่าน แล้วสร้าง doc ใน /users/{uid}
  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    // 1) สมัครบน Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // 2) ตั้ง displayName บน FirebaseAuth profile
    await cred.user!.updateDisplayName(displayName);

    // 3) คำนวน role
    final String assignedRole =
        (email.toLowerCase() == 'admin@admin.com') ? 'admin' : 'student';

    // 4) สร้างเอกสาร Firestore
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email.trim(),
      'displayName': displayName,
      'phone': phone ?? '',
      'role': assignedRole,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  /// ล็อกอินอีเมล/รหัสผ่านปกติ
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // กันกรณีเอกสารใน /users ยังไม่ถูกสร้าง (เช่นมีคนสร้าง user ผ่าน console)
    await ensureUserDocumentExists(firebaseUser: cred.user!);

    return cred;
  }

  /// ออกจากระบบ (รวม google ด้วย)
  Future<void> logout() async {
    await _auth.signOut();
    // ถ้าคุณใช้ GoogleSignIn() อยู่และอยาก signOut google ด้วยจริง ๆ
    // ให้ import google_sign_in แล้วทำ GoogleSignIn().signOut();
  }

  /// ดึงข้อมูลผู้ใช้ปัจจุบันจาก Firestore (/users/{uid})
  ///
  /// return:
  ///   - AppUser ถ้าเจอ doc
  ///   - null ถ้าไม่มี doc / ยังไม่ logged in
  ///
  /// *** สำคัญมากสำหรับ AuthGate ***
  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snap = await _db.collection('users').doc(user.uid).get();

      if (!snap.exists) {
        // ถ้ายังไม่มี doc -> พยายามสร้างอัตโนมัติ แล้วอ่านอีกรอบ
        await ensureUserDocumentExists(firebaseUser: user);
        final snap2 = await _db.collection('users').doc(user.uid).get();
        if (!snap2.exists || snap2.data() == null) {
          return null;
        }
        return AppUser.fromMap(uid: user.uid, data: snap2.data()!);
      }

      final data = snap.data();
      if (data == null) return null;

      return AppUser.fromMap(uid: user.uid, data: data);
    } catch (_) {
      // อย่าปล่อย error ทะลุขึ้นไปเพราะมันจะทำให้หน้า AuthGate จอดำ/แดง
      return null;
    }
  }

  /// แก้ไขโปรไฟล์ (ชื่อ / เบอร์)
  /// - อัปเดตทั้ง FirebaseAuth (displayName) และ Firestore (/users/{uid})
  Future<void> updateProfile({
    required String displayName,
    String? phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No current user');
    }

    // อัปเดต FirebaseAuth displayName
    await user.updateDisplayName(displayName);

    // อัปเดต Firestore
    await _db.collection('users').doc(user.uid).set(
      {
        'displayName': displayName,
        'phone': phone ?? '',
      },
      SetOptions(merge: true),
    );
  }

  /// ส่งลิงก์ reset password ไปอีเมล
  Future<void> sendResetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
