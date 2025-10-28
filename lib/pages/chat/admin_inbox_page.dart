import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'chat_page.dart';

class AdminInboxPage extends StatelessWidget {
  const AdminInboxPage({super.key});

  static const bgPage = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const cardBorder = Color(0x14000000); // black 8%
  static const primaryBlue = Color(0xFF2563EB);

  String _formatTime(dynamic ts) {
    if (ts == null) return "";
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final dd = dt.day.toString().padLeft(2, '0');
      final MM = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return "$dd/$MM/$yyyy $hh:$mm";
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          "กล่องข้อความ (Inbox)",
          style: TextStyle(
            fontSize: 18,
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.watchAllChatRoomsForAdmin(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "โหลดห้องแชทไม่สำเร็จ:\n${snap.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }

          final rooms = snap.data ?? [];
          if (rooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "ยังไม่มีการสนทนา",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "เมื่อผู้ใช้เริ่มแชท รายการจะแสดงที่นี่",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final room = rooms[i];
              final userUid = room['userUid'] ?? '';
              final displayName = room['displayName'] ?? userUid;
              final lastMsg = (room['lastMessage'] ?? '') as String;
              final updatedAt = room['updatedAt'];

              // การ์ดแต่ละห้องแบบ swipe เพื่อลบ
              return Dismissible(
                key: ValueKey(userUid),
                background: _buildSwipeBg(left: true),
                secondaryBackground: _buildSwipeBg(left: false),
                confirmDismiss: (_) async {
                  final ok = await _confirmDeleteDialog(
                    context,
                    displayName: displayName,
                  );
                  if (ok == true) {
                    await fs.deleteWholeChatRoom(userUid: userUid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text("ลบห้องของ $displayName แล้ว"),
                        ),
                      );
                    }
                  }
                  return ok ?? false;
                },
                child: _ChatRoomCard(
                  avatarLetter: displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : "?",
                  displayName: displayName,
                  previewText:
                      lastMsg.isEmpty ? "(ยังไม่มีรูปภาพ/ข้อความ)" : lastMsg,
                  timeStr: _formatTime(updatedAt),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          targetUserUid: userUid,
                          isAdminView: true,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // พื้นแดงเวลา swipe
  Widget _buildSwipeBg({required bool left}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment:
            left ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (left) ...[
            const Icon(Icons.delete, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              "ลบห้องแชท",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ] else ...[
            const Text(
              "ลบห้องแชท",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmDeleteDialog(
    BuildContext context, {
    required String displayName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          "ลบการสนทนา?",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "คุณต้องการลบห้องของ\n$displayName\nรวมข้อความทั้งหมดเลยหรือไม่?",
          style: const TextStyle(height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("ยกเลิก"),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.delete_forever),
            label: const Text(
              "ลบเลย",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------
// การ์ดห้องแชท 1 ห้อง (avatar + ชื่อ + preview + เวลา)
// ------------------------------------------------------
class _ChatRoomCard extends StatelessWidget {
  final String avatarLetter;
  final String displayName;
  final String previewText;
  final String timeStr;
  final VoidCallback onTap;

  static const textDark = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const primaryBlue = Color(0xFF2563EB);
  static const cardBorder = Color(0x14000000);

  const _ChatRoomCard({
    required this.avatarLetter,
    required this.displayName,
    required this.previewText,
    required this.timeStr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // avatar กล่อง
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primaryBlue,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // main text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // แถวบน: ชื่อ + เวลา
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: textDark,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: textMuted,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ข้อความล่าสุด
                    Text(
                      previewText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textMuted,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Chevron go-to-chat
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
