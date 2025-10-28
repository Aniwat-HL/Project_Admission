import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;

  // ผู้ส่ง
  final String senderUid;
  final String senderName;
  final String senderRole; // 'student' or 'admin'

  // เนื้อหา
  final String? text;
  final String type; // 'text' or 'image'
  final String? imageBase64;

  // เวลา
  final DateTime? createdAt;

  // ✅ ปฏิกิริยา (reactions)
  // โครงสร้างใน Firestore จะหน้าตาแบบนี้:
  // {
  //   "👍": ["uidA","uidB"],
  //   "❤️": ["uidC"]
  // }
  final Map<String, List<String>> reactions;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    required this.type,
    this.text,
    this.imageBase64,
    this.createdAt,
    required this.reactions,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    // --- createdAt ---
    DateTime? ts;
    final v = data['createdAt'];
    if (v is Timestamp) {
      ts = v.toDate();
    } else if (v is DateTime) {
      ts = v;
    }

    // --- reactions ---
    Map<String, List<String>> parsedReactions = {};
    final rawReactions = data['reactions'];
    if (rawReactions is Map<String, dynamic>) {
      rawReactions.forEach((emoji, uids) {
        if (uids is List) {
          parsedReactions[emoji] =
              uids.map((u) => u.toString()).toList();
        }
      });
    }

    return ChatMessage(
      id: id,
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      text: data['text'] as String?,
      type: (data['type'] as String?) ?? 'text',
      imageBase64: data['imageBase64'] as String?,
      createdAt: ts,
      reactions: parsedReactions, // ✅
    );
  }

  /// เผื่ออยากอัปเดต message ในอนาคต
  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': text,
      'type': type,
      'imageBase64': imageBase64,
      'createdAt': createdAt,
      'reactions': reactions,
    };
  }

  /// ใช้ตอนโชว์รูปใน UI
  ImageProvider? asImageProvider() {
    if (type != 'image') return null;
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    try {
      final bytes = base64Decode(imageBase64!);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
