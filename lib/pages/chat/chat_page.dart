import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final String targetUserUid; // ห้องนี้เป็นของนักเรียน uid นี้
  final bool isAdminView;     // true = admin กำลังดูห้องของเด็ก

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _fs = FirestoreService();
  final _msgCtl = TextEditingController();

  bool sending = false;
  String? errorMsg;

  String _chatTitle = "แชท";

  // typing indicator debounce
  Timer? _typingTimer;
  bool _iAmCurrentlyTyping = false;

  // room meta we listen (typing / lastSeen...)
  Map<String, dynamic>? _roomMeta;

  static const Color bgChat = Color(0xFFF5F7FA);
  static const Color myBubbleStart = Color(0xFF2563EB);
  static const Color myBubbleEnd = Color(0xFF1E40AF);
  static const Color otherBubble = Colors.white;
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMute = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initTitle();
    _startListenRoomMeta();
    _markSeen(); // mark seen ทันทีที่เข้า
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _typingTimer?.cancel();
    // เมื่อออกจากหน้าจอ เราจะ set typing=false ให้ตัวเอง
    _setTyping(false);
    super.dispose();
  }

  Future<void> _initTitle() async {
    if (!widget.isAdminView) {
      setState(() {
        _chatTitle = "ทีมเจ้าหน้าที่";
      });
      return;
    }
    final name = await _fs.getUserDisplayName(widget.targetUserUid);
    if (!mounted) return;
    setState(() {
      _chatTitle = name.length > 24 ? "${name.substring(0, 24)}..." : name;
    });
  }

  void _startListenRoomMeta() {
    _fs.watchChatRoomMeta(widget.targetUserUid).listen((data) {
      if (!mounted) return;
      setState(() {
        _roomMeta = data;
      });
      // เมื่อมีอัปเดต meta (เช่นเราเปิดจอ) เราก็ถือว่าเราเห็นข้อความล่าสุดแล้ว
      _markSeen();
    });
  }

  Future<void> _markSeen() async {
    // mark ว่าเราเห็นแล้ว (update lastSeenByX)
    await _fs.markRoomSeen(
      roomUserUid: widget.targetUserUid,
      isAdminViewer: widget.isAdminView,
    );
  }

  // ---------- typing logic ----------
  void _onUserTypingChanged(String _) {
    // ถูกเรียกทุกครั้งที่ user พิมพ์ใน TextField
    // เราจะ set typing=true (ถ้ายังไม่ได้เป็น true)
    _setTyping(true);

    // แล้วตั้ง timer ถ้า 2 วินาทีเงียบ ให้ typing=false
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool typing) async {
    // ถ้าสถานะไม่มีเปลี่ยนก็ไม่ยิงไป firestore ลด write
    if (_iAmCurrentlyTyping == typing) return;
    _iAmCurrentlyTyping = typing;

    await _fs.setTypingStatus(
      roomUserUid: widget.targetUserUid,
      isAdmin: widget.isAdminView,
      typing: typing,
    );
  }

  // ---------- send text ----------
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

    // หลังส่งข้อความ ให้ mark ว่าเราไม่กำลังพิมพ์แล้ว
    _setTyping(false);

    // และอัปเดตว่าเราเห็นห้อง (กันเคส unread ค้างฝั่งเราเอง)
    _markSeen();
  }

  // ---------- send image (student only) ----------
  Future<void> _handleSendImage() async {
    if (widget.isAdminView) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;

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

    _setTyping(false);
    _markSeen();
  }

  // ---------- delete message ----------
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

  // ---------- reactions ----------
  Future<void> _toggleReaction(ChatMessage m, String emoji) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final uid = me.uid;

    final current = m.reactions;
    final newReactions = <String, List<String>>{};
    current.forEach((k, v) {
      newReactions[k] = List<String>.from(v);
    });

    final list = List<String>.from(newReactions[emoji] ?? []);
    if (list.contains(uid)) {
      list.remove(uid);
    } else {
      list.add(uid);
    }

    if (list.isEmpty) {
      newReactions.remove(emoji);
    } else {
      newReactions[emoji] = list;
    }

    await _fs.updateMessageReactions(
      roomUserUid: widget.targetUserUid,
      messageId: m.id,
      reactionsMap: newReactions,
    );
  }

  Future<void> _onLongPressMessage(ChatMessage m, bool isMe) async {
    final emojiList = ["👍","❤️","😂","😮","😢","🔥"];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojiList.map((e) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _toggleReaction(m, e);
                    },
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 28),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    "ลบข้อความนี้",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _confirmDeleteMessage(m, isMe);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- read receipt helper ----------
  // คืน true ถ้า "ฝั่งตรงข้าม" เห็นข้อความนี้แล้ว
  bool _isMessageSeenByOther(ChatMessage myMsg, Map<String, dynamic>? meta) {
    if (meta == null) return false;
    // กำหนดว่าใครคือ 'other'
    // ถ้าเราเป็น admin -> other = student -> lastSeenByStudent
    // ถ้าเราเป็น student -> other = admin -> lastSeenByAdmin
    final otherSeenField =
        widget.isAdminView ? 'lastSeenByStudent' : 'lastSeenByAdmin';

    final rawTs = meta[otherSeenField];
    if (rawTs is Timestamp && myMsg.createdAt != null) {
      final seenAt = rawTs.toDate();
      return !seenAt.isBefore(myMsg.createdAt!);
    }
    return false;
  }

  // ---------- reactions bar ----------
  Widget _buildReactionsBar(ChatMessage m, bool isMe) {
    if (m.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = m.reactions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? Colors.white.withOpacity(0.3)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: entries.map((e) {
          final emoji = e.key;
          final count = e.value.length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------- single bubble (with "อ่านแล้ว" ใต้ last bubble ของฉัน) ----------
  Widget _buildBubble(
    ChatMessage m,
    bool isMe,
    bool showName,
    bool isLastMyMessage,
  ) {
    final isImage = (m.type == 'image' && m.imageBase64 != null);
    final imgProvider = m.asImageProvider();

    final Alignment align =
        isMe ? Alignment.centerRight : Alignment.centerLeft;

    final BoxDecoration boxDeco = isMe
        ? BoxDecoration(
            gradient: const LinearGradient(
              colors: [myBubbleStart, myBubbleEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
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
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final textStyle = isMe
        ? const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)
        : const TextStyle(fontSize: 15, color: textDark, height: 1.4);

    final nameStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: isMe ? Colors.white70 : textMute,
      height: 1.3,
    );

    // ตัดสิน read receipt
    final bool seenByOther =
        isMe && isLastMyMessage && _isMessageSeenByOther(m, _roomMeta);

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: () {
          _onLongPressMessage(m, isMe);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // main bubble
                Container(
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

                // reactions
                _buildReactionsBar(m, isMe),

                // seen / delivered (เฉพาะ bubble สุดท้ายของฉัน)
                if (seenByOther)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "อ่านแล้ว",
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.black54 : Colors.black45,
                      ),
                    ),
                  )
                else if (isMe && isLastMyMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "ส่งแล้ว",
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.black38 : Colors.black38,
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

  // ---------- typing indicator row (ใต้ message list, เหนือ input) ----------
  Widget _buildTypingIndicator() {
    // เราจะโชว์เฉพาะ "อีกฝั่งกำลังพิมพ์"
    final bool otherTyping = widget.isAdminView
        ? (_roomMeta?['typing_student'] == true)
        : (_roomMeta?['typing_admin'] == true);

    if (!otherTyping) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 4),
                color: Colors.black.withOpacity(.05),
              ),
            ],
          ),
          child: const Text(
            "กำลังพิมพ์...",
            style: TextStyle(
              fontSize: 12,
              color: textMute,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  // ---------- input area ----------
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
                if (!widget.isAdminView) ...[
                  IconButton(
                    onPressed: sending ? null : _handleSendImage,
                    icon: const Icon(Icons.image_outlined),
                    color: const Color(0xFF2563EB),
                    tooltip: "ส่งรูป (เช่น สลิปโอน)",
                  ),
                  const SizedBox(width: 4),
                ],

                Expanded(
                  child: TextField(
                    controller: _msgCtl,
                    onChanged: _onUserTypingChanged,
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
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                        borderSide: BorderSide(
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

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
                                color: const Color(0xFF2563EB)
                                    .withOpacity(0.4),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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

  // ---------- header ----------
  PreferredSizeWidget _buildHeader() {
    final bool otherTyping = widget.isAdminView
        ? (_roomMeta?['typing_student'] == true)
        : (_roomMeta?['typing_admin'] == true);

    final subtitleText = otherTyping
        ? "กำลังพิมพ์..."
        : (widget.isAdminView ? "ห้องนักเรียน" : "ตอบโดยเจ้าหน้าที่");

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 60,
      automaticallyImplyLeading: true,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        children: [
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
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

                // หาข้อความสุดท้ายที่ "ฉัน" เป็นคนส่ง
                final meIsAdmin = widget.isAdminView;
                int lastMyIndex = -1;
                for (int i = msgs.length - 1; i >= 0; i--) {
                  final mm = msgs[i];
                  final bool isMe = meIsAdmin
                      ? (mm.senderRole == 'admin')
                      : (mm.senderRole == 'student');
                  if (isMe) {
                    lastMyIndex = i;
                    break;
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];

                    final bool isMe = meIsAdmin
                        ? (m.senderRole == 'admin')
                        : (m.senderRole == 'student');

                    final bool showName = widget.isAdminView ? !isMe : false;

                    final bool isLastMyMessage = (i == lastMyIndex);

                    return _buildBubble(
                      m,
                      isMe,
                      showName,
                      isLastMyMessage,
                    );
                  },
                );
              },
            ),
          ),

          // typing indicator ("อีกฝั่งกำลังพิมพ์...")
          _buildTypingIndicator(),

          // error bar ด้านบน input
          if (errorMsg != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
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

          // input area
          _buildInputArea(),
        ],
      ),
    );
  }
}
