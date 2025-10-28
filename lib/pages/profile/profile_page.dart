import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admission_app/services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();

  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();

  bool saving = false;
  String? saveMsg;

  bool _loadingProfile = true;
  String _role = "student"; // default ถ้ายังโหลดไม่ทัน

  // โทนสีกลางของแอป
  static const Color bgPage = Color(0xFFF5F7FA);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1E40AF);

  @override
  void initState() {
    super.initState();
    _initLocalFromAuth();
    _loadUserProfileFromFirestore();
  }

  // ใส่ค่าจาก FirebaseAuth ทันที เพื่อไม่ให้ field ว่างระหว่างรอ Firestore
  void _initLocalFromAuth() {
    final user = _auth.currentUser;
    _nameCtl.text = user?.displayName ?? '';
    _emailCtl.text = user?.email ?? '';
    _phoneCtl.text = '';
  }

  // ดึง role / phone / displayName ที่แท้จริงจาก Firestore: users/{uid}
  Future<void> _loadUserProfileFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingProfile = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data();
      if (data != null) {
        final displayName = (data['displayName'] ?? '') as String;
        final phone = (data['phone'] ?? '') as String;
        final role = (data['role'] ?? 'student') as String;

        // อัปเดต textfield ถ้ามีค่า (กันกรณีเป็นค่าว่างไม่ต้อง override)
        if (displayName.isNotEmpty) _nameCtl.text = displayName;
        if (phone.isNotEmpty) _phoneCtl.text = phone;
        _role = role;
      }
    } catch (e) {
      // ถ้าดึง Firestore พลาด เราจะไม่ crash แค่ไม่เติมเพิ่ม
      // debugPrint("load user profile error: $e");
    }

    if (!mounted) return;
    setState(() {
      _loadingProfile = false;
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() {
      saving = true;
      saveMsg = null;
    });

    try {
      await _auth.updateProfile(
        displayName: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        saveMsg = 'บันทึกโปรไฟล์เรียบร้อย 🎉';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saveMsg = 'เกิดข้อผิดพลาด: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        saving = false;
      });
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // สร้าง input field reuse
  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: textMuted,
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.black.withOpacity(.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: primaryBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // เลือกสี badge ตาม role
    final bool isAdmin = _role.toLowerCase() == 'admin';

    final badgeBg = isAdmin
        ? const Color(0xFFEDE9FE) // ม่วงจาง
        : primaryBlue.withOpacity(.08); // ฟ้าจาง

    final badgeBorder = isAdmin
        ? const Color(0xFF8B5CF6).withOpacity(.35) // ม่วงเข้ม borderline
        : primaryBlue.withOpacity(.3);

    final badgeTextColor = isAdmin
        ? const Color(0xFF6D28D9) // ม่วงเข้ม
        : primaryBlue;

    final badgeLabel = isAdmin ? "เจ้าหน้าที่" : "นักเรียน";

    // ตัวอักษรใน avatar
    final displayInitial = (() {
      final n = _nameCtl.text.trim();
      if (n.isNotEmpty) return n[0].toUpperCase();
      if (_emailCtl.text.isNotEmpty) return _emailCtl.text[0].toUpperCase();
      return 'U';
    })();

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'โปรไฟล์ของฉัน',
          style: TextStyle(
            fontSize: 16,
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
      body: SafeArea(
        child: _loadingProfile
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== PROFILE CARD =====
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
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
                      child: Row(
                        children: [
                          // Avatar gradient
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: isAdmin
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6), // purple
                                        Color(0xFF4C1D95),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        primaryBlue,
                                        primaryBlueDark,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isAdmin
                                          ? const Color(0xFF8B5CF6)
                                          : primaryBlue)
                                      .withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                displayInitial,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Name + email + badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ชื่อ
                                Text(
                                  _nameCtl.text.isNotEmpty
                                      ? _nameCtl.text.trim()
                                      : "ยังไม่มีชื่อ",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // อีเมล
                                Text(
                                  _emailCtl.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: textMuted,
                                    height: 1.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 8),

                                // badge role
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: badgeBorder,
                                    ),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: TextStyle(
                                      color: badgeTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== EDIT CARD =====
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ข้อมูลส่วนตัว",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "อัปเดตข้อมูลเพื่อติดต่อได้ง่ายขึ้น",
                            style: TextStyle(
                              fontSize: 13,
                              color: textMuted,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Email (readOnly)
                          _buildInputField(
                            label: "อีเมล",
                            icon: Icons.email_outlined,
                            controller: _emailCtl,
                            readOnly: true,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          // Name (แก้ได้)
                          _buildInputField(
                            label: "ชื่อที่แสดง",
                            icon: Icons.person_outline,
                            controller: _nameCtl,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 16),

                          // Phone (แก้ได้)
                          _buildInputField(
                            label: "เบอร์โทร",
                            icon: Icons.phone_outlined,
                            controller: _phoneCtl,
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 20),

                          if (saveMsg != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: saveMsg!.startsWith('เกิด')
                                    ? Colors.red.withOpacity(.08)
                                    : Colors.green.withOpacity(.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: saveMsg!.startsWith('เกิด')
                                      ? Colors.red.withOpacity(.4)
                                      : Colors.green.withOpacity(.4),
                                ),
                              ),
                              child: Text(
                                saveMsg!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: saveMsg!.startsWith('เกิด')
                                      ? Colors.red
                                      : Colors.green.shade700,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.zero,
                                elevation: 3,
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      "บันทึกโปรไฟล์",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== LOGOUT CARD =====
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ออกจากระบบ",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "หากออกจากระบบ คุณจะต้องเข้าสู่ระบบอีกครั้งเพื่อดูสถานะการสมัครและแชทกับเจ้าหน้าที่",
                            style: TextStyle(
                              fontSize: 13,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.red.withOpacity(.4),
                                ),
                                foregroundColor: Colors.red.shade700,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _logout,
                              icon: const Icon(Icons.logout),
                              label: const Text(
                                "ออกจากระบบ",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        isAdmin
                            ? "เวอร์ชันเจ้าหน้าที่ (admin view)"
                            : "เวอร์ชันแอปนักเรียน",
                        style: const TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
