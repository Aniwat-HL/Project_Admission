import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/auth_service.dart';
import '../auth/forgot_password_page.dart';
import '../auth/register_page.dart';

// ✅ import AuthGate เพื่อนำทางหลังล็อกอิน
import '../../main.dart'; // ตรวจให้ชัวร์ว่า path ถูก: main.dart อยู่ใน lib/ ใช้ '../../main.dart'

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();

  bool loadingEmail = false;
  bool loadingGoogle = false;
  String? errorMsg;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  // ---------------------------
  // Login ด้วยอีเมล/รหัสผ่าน
  // ---------------------------
  Future<void> _loginWithEmail() async {
    setState(() {
      loadingEmail = true;
      errorMsg = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _passCtl.text.trim(),
      );

      if (!mounted) return;

      // 🔁 เดิม: Navigator.pop();
      // ใหม่: เคลียร์ stack แล้วพาไป AuthGate (ซึ่งจะเลือกหน้า home ให้เอง)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMsg = e.message ?? "ล็อกอินไม่สำเร็จ";
      });
    } catch (e) {
      setState(() {
        errorMsg = "เกิดข้อผิดพลาด: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingEmail = false;
        });
      }
    }
  }

  // ---------------------------
  // Login ด้วย Google
  // ---------------------------
  Future<void> _loginWithGoogle() async {
    setState(() {
      loadingGoogle = true;
      errorMsg = null;
    });

    try {
      // 1) popup เลือกบัญชี Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // ผู้ใช้กดยกเลิก
        setState(() {
          loadingGoogle = false;
        });
        return;
      }

      // 2) ดึง token จาก Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3) สร้าง credential ของ Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4) Sign in Firebase
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 5) ถ้ายังไม่มี doc /users/{uid} ให้สร้าง
      final currentUser = userCred.user;
      if (currentUser != null) {
        await AuthService().ensureUserDocumentExists(
          firebaseUser: currentUser,
        );
      }

      if (!mounted) return;

      // 🔁 เดิม: Navigator.pop();
      // ใหม่: ไป AuthGate แบบเคลียร์ stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMsg = "เกิดข้อผิดพลาด Google: ${e.message}";
      });
    } catch (e) {
      setState(() {
        errorMsg = "เกิดข้อผิดพลาด Google: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          loadingGoogle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPress = !loadingEmail && !loadingGoogle;

    final bg = const Color(0xFFF5F7FA); // สีฉากหลังอ่อน ๆ
    final cardRadius = BorderRadius.circular(20);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: cardRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.black.withOpacity(0.03),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: Colors.blueGrey.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "ยินดีต้อนรับ 👋",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "เข้าสู่ระบบเพื่อสมัครคอร์ส / ติดตามสถานะ",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // email
                    const Text(
                      "อีเมล",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "name@example.com",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "รหัสผ่าน",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // error
                    if (errorMsg != null) ...[
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canPress ? _loginWithEmail : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: loadingEmail
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                "เข้าสู่ระบบ",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade600,
                        ),
                        onPressed: canPress
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              }
                            : null,
                        child: const Text(
                          "ลืมรหัสผ่าน?",
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // divider "หรือ"
                    Row(
                      children: [
                        Expanded(
                          child: Container(height: 1, color: Colors.black12),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "หรือเข้าสู่ระบบด้วย",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: Colors.black12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // google login button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: canPress ? _loginWithGoogle : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.black87,
                          backgroundColor: Colors.white,
                        ),
                        icon: loadingGoogle
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text(
                          "เข้าสู่ระบบด้วย Google",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Divider(color: Colors.black12, height: 1),
                    const SizedBox(height: 20),

                    // signup row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "ยังไม่มีบัญชี?",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: canPress
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            "สมัครสมาชิก",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
