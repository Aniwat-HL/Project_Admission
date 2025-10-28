import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;

  // ใครส่ง
  final String senderUid;
  final String senderName;
  final String senderRole; // 'student' or 'admin'

  // เนื้อหา
  final String? text;
  final String? type; // 'text' (default) or 'image'
  final String? imageBase64;

  // เวลา
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    this.text,
    this.type,
    this.imageBase64,
    this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    DateTime? ts;
    final v = data['createdAt'];
    if (v is Timestamp) {
      ts = v.toDate();
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
    );
  }

  /// สำหรับโชว์รูปใน UI
  ImageProvider? asImageProvider() {
    if (type != 'image') return null;
    if (imageBase64 == null) return null;
    try {
      final bytes = base64Decode(imageBase64!);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
