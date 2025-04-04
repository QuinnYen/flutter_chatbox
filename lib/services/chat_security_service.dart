import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chatbox/models/message.dart';

class ChatSecurityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 安全日誌記錄
  Future<void> logSecurityEvent(String eventType, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      final now = DateTime.now();

      await _firestore.collection('security_logs').add({
        'eventType': eventType,
        'userId': user?.uid,
        'email': user?.email,
        'timestamp': Timestamp.fromDate(now),
        'data': data,
      });

      if (kDebugMode) {
        print('Security Event: $eventType, User: ${user?.email}, Data: $data');
      }
    } catch (e) {
      // 記錄失敗不應中斷主要功能
      if (kDebugMode) {
        print('Failed to log security event: $e');
      }
    }
  }

  // 檢測可能的敏感內容
  bool containsSensitiveContent(String text) {
    // 這個函數可以用於檢測並過濾各種敏感內容
    // 實際應用中可能會使用更複雜的演算法或外部API

    // 簡單的敏感內容檢測（實際應用中會更複雜）
    final sensitivePatterns = [
      RegExp(r'\b(?:\d[ -]*?){13,16}\b'), // 信用卡號碼
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'), // 電子郵件
      // 可以添加更多敏感信息的模式
    ];

    for (var pattern in sensitivePatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }

    return false;
  }

  // 處理訊息的敏感內容
  String processSensitiveContent(String text) {
    // 檢測並遮蔽敏感資訊

    // 遮蔽信用卡號碼
    text = text.replaceAllMapped(
      RegExp(r'\b(?:\d[ -]*?){13,16}\b'),
          (match) => '************' + match.group(0)!.substring(match.group(0)!.length - 4),
    );

    // 遮蔽電子郵件
    text = text.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
          (match) {
        final parts = match.group(0)!.split('@');
        if (parts.length == 2) {
          final name = parts[0];
          return name.substring(0, name.length > 2 ? 2 : 1) + '***@' + parts[1];
        }
        return '***@***.***';
      },
    );

    return text;
  }

  // 檢查訊息是否濫用（頻率控制）
  Future<bool> isMessageSpam(String userId, String roomId) async {
    try {
      // 取得過去 60 秒內的訊息數量
      final now = DateTime.now();
      final sixtySecondsAgo = now.subtract(const Duration(seconds: 60));

      final querySnapshot = await _firestore
          .collection('messages')
          .doc(roomId)
          .collection('chatMessages')
          .where('senderId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sixtySecondsAgo))
          .get();

      // 如果在過去 60 秒內發送了超過 10 條訊息，則視為濫用
      return querySnapshot.docs.length >= 10;
    } catch (e) {
      // 發生錯誤時，不阻止訊息發送
      if (kDebugMode) {
        print('Error checking message spam: $e');
      }
      return false;
    }
  }

  // 為訊息內容生成雜湊值（用於驗證完整性）
  String generateMessageHash(Message message) {
    final data = {
      'senderId': message.senderId,
      'text': message.text,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'type': message.type.toString(),
    };

    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  // 驗證訊息的完整性
  bool verifyMessageIntegrity(Message message, String expectedHash) {
    final actualHash = generateMessageHash(message);
    return actualHash == expectedHash;
  }

  // 檢查訊息是否來自授權的聊天室成員
  Future<bool> isAuthorizedParticipant(String userId, String roomId) async {
    try {
      final roomDoc = await _firestore.collection('chatRooms').doc(roomId).get();

      if (!roomDoc.exists) return false;

      final participantIds = List<String>.from(roomDoc.data()?['participantIds'] ?? []);
      return participantIds.contains(userId);
    } catch (e) {
      // 發生錯誤時，預設為未授權
      if (kDebugMode) {
        print('Error checking authorization: $e');
      }
      return false;
    }
  }
}