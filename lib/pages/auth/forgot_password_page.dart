import 'package:flutter/material.dart';
import 'package:admission_app/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtl = TextEditingController();
  final _auth = AuthService();

  bool sending = false;
  String? infoMsg;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtl.text.trim();

    if (email.isEmpty) {
      setState(() {
        infoMsg = "กรุณากรอกอีเมลก่อน";
      });
      return;
    }

    setState(() {
      sending = true;
      infoMsg = null;
    });

    try {
      await _auth.sendResetPassword(email);
      setState(() {
        infoMsg =
            "ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว ✅\n"
            "กรุณาเช็คกล่องจดหมาย (รวมถึงโฟลเดอร์สแปม/จดหมายขยะ)\n"
            "แล้วกดปุ่มตั้งรหัสผ่านใหม่ในอีเมล";
      });
    } catch (e) {
      setState(() {
        infoMsg = "ส่งไม่สำเร็จ: $e";
      });
    } finally {
      setState(() {
        sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF5F7FA);
    final cardRadius = BorderRadius.circular(20);
    final canPress = !sending;

    final bool isError =
        infoMsg != null && infoMsg!.startsWith("ส่งไม่สำเร็จ");

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
                    // ---------- Header ----------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.blueGrey.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "ลืมรหัสผ่านใช่ไหม?",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "พิมพ์อีเมลที่ใช้สมัคร เราจะส่งลิงก์ตั้งรหัสผ่านใหม่ไปให้",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ---------- Email label ----------
                    const Text(
                      "อีเมลที่ใช้สมัคร",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ---------- Email field ----------
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

                    // ---------- Helper text / instructions ----------
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blueGrey.shade100,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Colors.blueGrey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "หลังจากกด 'ส่งลิงก์รีเซ็ตรหัสผ่าน':\n"
                              "1. เปิดอีเมลของคุณ\n"
                              "2. ถ้าไม่เจอ ให้เช็คโฟลเดอร์สแปม / จดหมายขยะ\n"
                              "3. กดลิงก์ในอีเมลเพื่อสร้างรหัสผ่านใหม่ "
                              "แล้วตั้งรหัสที่จำได้ง่ายแต่ไม่เดาง่าย 🔒",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- Result / status message ----------
                    if (infoMsg != null) ...[
                      Text(
                        infoMsg!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isError ? Colors.red : Colors.green,
                          fontWeight: isError ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ---------- Send button ----------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canPress ? _sendReset : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text(
                                "ส่งลิงก์รีเซ็ตรหัสผ่าน",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Divider(color: Colors.black12, height: 1),
                    const SizedBox(height: 20),

                    // ---------- Back to login ----------
                    Center(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blueGrey.shade700,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text(
                          "ย้อนกลับไปหน้าเข้าสู่ระบบ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
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
