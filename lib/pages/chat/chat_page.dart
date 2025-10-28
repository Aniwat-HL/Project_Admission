import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../models/chat_message.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.targetUserUid,
    required this.isAdminView,
  });

  /// student ปกติ:
  ///   targetUserUid = currentUser.uid
  ///   isAdminView = false
  ///
  /// admin ดูห้องของนักเรียน:
  ///   targetUserUid = uid นักเรียน
  ///   isAdminView = true
  final String targetUserUid;
  final bool isAdminView;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _fs = FirestoreService();
  final _msgCtl = TextEditingController();

  bool sending = false;
  String? errorMsg;

  // ชื่อบน AppBar
  String _chatTitle = "แชท";

  // Theme tokens
  static const Color bgChat = Color(0xFFF5F7FA);
  static const Color myBubbleStart = Color(0xFF2563EB);
  static const Color myBubbleEnd = Color(0xFF1E40AF); // ฟ้าเข้มลง
  static const Color otherBubble = Colors.white;
  static const Color borderSoft = Color(0x14000000); // 8% black
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMute = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initTitle();
  }

  Future<void> _initTitle() async {
    if (!widget.isAdminView) {
      // ฝั่งนักเรียน เห็นเป็นเจ้าหน้าที่
      setState(() {
        _chatTitle = "ทีมเจ้าหน้าที่";
      });
      return;
    }

    // ฝั่งแอดมิน: ดึงชื่อเด็กมาโชว์
    final name = await _fs.getUserDisplayName(widget.targetUserUid);
    if (!mounted) return;
    setState(() {
      _chatTitle = name.length > 24 ? "${name.substring(0, 24)}..." : name;
    });
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    super.dispose();
  }

  // -----------------------------
  // ส่งข้อความตัวอักษร
  // -----------------------------
  Future<void> _handleSendText() async {
    final txt = _msgCtl.text.trim();
    if (txt.isEmpty) return;

    if (!mounted) return;
    setState(() {
      sending = true;
      errorMsg = null;
    });

    String? err;

    if (widget.isAdminView) {
      // แอดมินตอบในห้องของนักเรียน targetUserUid
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) {
        err = "ยังไม่ได้ล็อกอินเป็น admin";
      } else {
        err = await _fs.sendMessageFromAdmin(
          targetUserUid: widget.targetUserUid,
          adminUid: adminUser.uid,
          adminName: adminUser.displayName ?? "Admin",
          text: txt,
        );
      }
    } else {
      // นักเรียนส่งในห้องของตัวเอง
      final studentUser = FirebaseAuth.instance.currentUser;
      if (studentUser == null) {
        err = "ยังไม่ได้ล็อกอิน";
      } else {
        err = await _fs.sendMessageFromStudent(
          studentUid: studentUser.uid,
          studentName: studentUser.displayName ?? "ฉัน",
          text: txt,
        );
      }
    }

    if (!mounted) return;
    setState(() {
      sending = false;
      if (err == null) {
        _msgCtl.clear();
      } else {
        errorMsg = err;
      }
    });
  }

  // -----------------------------
  // นักเรียนเท่านั้น: แนบรูป (เช่นสลิป)
  // -----------------------------
  Future<void> _handleSendImage() async {
    if (widget.isAdminView) {
      // ยังไม่ให้แอดมินส่งรูปจากหน้านี้
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );

    if (picked == null) {
      return;
    }

    final fileBytes = await picked.readAsBytes();
    if (fileBytes.isEmpty) {
      setState(() {
        errorMsg = "เลือกรูปไม่สำเร็จ";
      });
      return;
    }

    final studentUser = FirebaseAuth.instance.currentUser;
    if (studentUser == null) {
      setState(() {
        errorMsg = "ยังไม่ได้ล็อกอิน";
      });
      return;
    }

    setState(() {
      sending = true;
      errorMsg = null;
    });

    final err = await _fs.sendImageFromStudent(
      studentUid: studentUser.uid,
      studentName: studentUser.displayName ?? "ฉัน",
      imageBytes: fileBytes,
    );

    if (!mounted) return;
    setState(() {
      sending = false;
      if (err != null) {
        errorMsg = err;
      }
    });
  }

  // -----------------------------
  // ลบข้อความ (เฉพาะของตัวเอง)
  // -----------------------------
  Future<void> _confirmDeleteMessage(ChatMessage m, bool isMe) async {
    if (!isMe) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ลบข้อความนี้?"),
        content: const Text("คุณต้องการลบข้อความนี้สำหรับทุกคนหรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete),
            label: const Text("ลบ"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _fs.deleteSingleMessage(
        roomUserUid: widget.targetUserUid,
        messageId: m.id,
      );
    }
  }

  // -----------------------------
  // bubble UI
  // -----------------------------
  Widget _buildBubble(ChatMessage m, bool isMe, bool showName) {
    final isImage = (m.type == 'image' && m.imageBase64 != null);
    final imgProvider = m.asImageProvider();

    // สีและ alignment
    final Alignment align =
        isMe ? Alignment.centerRight : Alignment.centerLeft;

    final BoxDecoration boxDeco = isMe
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [myBubbleStart, myBubbleEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          )
        : BoxDecoration(
            color: otherBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final textStyle = isMe
        ? const TextStyle(
            fontSize: 15,
            color: Colors.white,
            height: 1.4,
          )
        : const TextStyle(
            fontSize: 15,
            color: textDark,
            height: 1.4,
          );

    final nameStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: isMe ? Colors.white70 : textMute,
      height: 1.3,
    );

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: () {
          _confirmDeleteMessage(m, isMe);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 260,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: boxDeco,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName && m.senderName.isNotEmpty) ...[
                  Text(m.senderName, style: nameStyle),
                  const SizedBox(height: 4),
                ],
                if (isImage && imgProvider != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image(
                      image: imgProvider,
                      width: 220,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Text(m.text ?? "", style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // ช่องส่งข้อความด้านล่าง
  // -----------------------------
  Widget _buildInputArea() {
    final canSend = _msgCtl.text.trim().isNotEmpty && !sending;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.07),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.black.withOpacity(.05),
              ),
            ),
            child: Row(
              children: [
                // ปุ่มเลือกรูป (นักเรียนเท่านั้น)
                if (!widget.isAdminView) ...[
                  IconButton(
                    onPressed: sending ? null : _handleSendImage,
                    icon: const Icon(Icons.image_outlined),
                    color: const Color(0xFF2563EB),
                    tooltip: "ส่งรูป (เช่น สลิปโอน)",
                  ),
                  const SizedBox(width: 4),
                ],

                // กล่องข้อความ
                Expanded(
                  child: TextField(
                    controller: _msgCtl,
                    onChanged: (_) {
                      // เพื่อรีเฟรชปุ่มส่ง enable/disable
                      setState(() {});
                    },
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "พิมพ์ข้อความ...",
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: textMute,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.07),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.07),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ปุ่มส่ง
                InkWell(
                  onTap: canSend ? _handleSendText : null,
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: canSend
                          ? const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: canSend ? null : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: canSend
                          ? [
                              BoxShadow(
                                color:
                                    const Color(0xFF2563EB).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: canSend ? Colors.white : Colors.white70,
                              size: 20,
                            ),
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

  // -----------------------------
  // header / AppBar
  // -----------------------------
  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 60,
      automaticallyImplyLeading: true,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
          // avatar-ish
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chatTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    height: 1.2,
                  ),
                ),
                Text(
                  widget.isAdminView
                      ? "ห้องนักเรียน"
                      : "ตอบโดยเจ้าหน้าที่",
                  style: const TextStyle(
                    fontSize: 12,
                    color: textMute,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.black.withOpacity(0.06),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Stream<List<ChatMessage>> stream = widget.isAdminView
        ? _fs.watchChatOfUser(widget.targetUserUid)
        : _fs.watchMyChat(widget.targetUserUid);

    return Scaffold(
      backgroundColor: bgChat,
      appBar: _buildHeader(),
      body: Column(
        children: [
          // รายการข้อความ
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "โหลดข้อความไม่สำเร็จ:\n${snap.error}",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "ยังไม่มีข้อความ\nพิมพ์ข้อความแรกของคุณได้เลย 👋",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMute,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];

                    // "เรา" คือใคร?
                    final bool isMe = widget.isAdminView
                        ? (m.senderRole == 'admin')
                        : (m.senderRole == 'student');

                    // ถ้าเป็น adminView -> ให้โชว์ชื่อฝั่งตรงข้าม (นักเรียน)
                    final bool showName = widget.isAdminView ? !isMe : false;

                    return _buildBubble(m, isMe, showName);
                  },
                );
              },
            ),
          ),

          // error bar (เช่น ส่งรูป fail ฯลฯ)
          if (errorMsg != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(.4),
                  ),
                ),
                child: Text(
                  errorMsg!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    height: 1.4,
                  ),
                ),
              ),
            ),

          // แถวพิมพ์/ปุ่มส่ง
          _buildInputArea(),
        ],
      ),
    );
  }
}
