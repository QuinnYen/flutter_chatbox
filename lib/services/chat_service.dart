import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_chatbox/models/chat_room.dart';
import 'package:flutter_chatbox/models/message.dart';
import 'package:flutter_chatbox/models/chat_user.dart';
import 'package:flutter_chatbox/services/chat_security_service.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ChatSecurityService _securityService = ChatSecurityService();

  // 取得聊天室參與者資訊
  Future<List<ChatUser>> getChatRoomParticipants(String roomId) async {
    try {
      // 取得聊天室資料
      final roomDoc = await _firestore.collection('chatRooms').doc(roomId).get();
      if (!roomDoc.exists) return [];

      final participantIds = List<String>.from(roomDoc.data()?['participantIds'] ?? []);
      final List<ChatUser> participants = [];

      // 取得每個參與者的資料
      for (final userId in participantIds) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          participants.add(ChatUser(
            id: userDoc.id,
            name: userDoc.data()?['name'] ?? '',
            email: userDoc.data()?['email'] ?? '',
            photoUrl: userDoc.data()?['photoUrl'] ?? '',
            lastActive: (userDoc.data()?['lastActive'] as Timestamp?)?.toDate(),
          ));
        }
      }

      return participants;
    } catch (e) {
      return [];
    }
  }

  // 取得聊天室資訊
  Stream<ChatRoom?> getChatRoom(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return ChatRoom.fromFirestore(doc);
      }
      return null;
    });
  }

  // 取得目前使用者的ID
  String? get currentUserId => _auth.currentUser?.uid;

  // 發送文字訊息 (整合安全處理)
  Future<void> sendTextMessage({
    required String roomId,
    required String text,
  }) async {
    if (currentUserId == null) return;

    // 檢查發送者是否為聊天室成員
    final isAuthorized = await _securityService.isAuthorizedParticipant(
      currentUserId!,
      roomId,
    );

    if (!isAuthorized) {
      await _securityService.logSecurityEvent(
        'unauthorized_message_attempt',
        {
          'userId': currentUserId,
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      throw Exception('您不是此聊天室的成員');
    }

    // 檢查訊息頻率
    final isSpam = await _securityService.isMessageSpam(currentUserId!, roomId);
    if (isSpam) {
      await _securityService.logSecurityEvent(
        'message_spam_detected',
        {
          'userId': currentUserId,
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      throw Exception('訊息發送過於頻繁，請稍後再試');
    }

    // 處理敏感內容
    String processedText = text;
    if (_securityService.containsSensitiveContent(text)) {
      processedText = _securityService.processSensitiveContent(text);

      await _securityService.logSecurityEvent(
        'sensitive_content_detected',
        {
          'userId': currentUserId,
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }

    // 取得發送者資訊
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // 建立訊息文件
    final messageRef = _firestore
        .collection('messages')
        .doc(roomId)
        .collection('chatMessages')
        .doc();

    final now = DateTime.now();

    // 準備訊息資料
    final messageData = {
      'roomId': roomId,
      'senderId': currentUserId,
      'senderName': userData['name'] ?? 'Unknown User',
      'senderPhotoUrl': userData['photoUrl'] ?? '',
      'text': processedText,
      'originalText': text != processedText ? text : null, // 儲存原始文字，僅供發送者查看
      'timestamp': Timestamp.fromDate(now),
      'type': 'text',
      'status': 'sent',
      'readBy': [currentUserId],
    };

    // 產生訊息哈希值
    final message = Message(
      id: messageRef.id,
      roomId: roomId,
      senderId: currentUserId!,
      senderName: userData['name'] ?? 'Unknown User',
      senderPhotoUrl: userData['photoUrl'] ?? '',
      text: processedText,
      timestamp: now,
      type: MessageType.text,
      status: MessageStatus.sent,
      readBy: [currentUserId!],
    );

    final messageHash = _securityService.generateMessageHash(message);

    // 添加哈希值到訊息資料
    messageData['hash'] = messageHash;

    // 儲存訊息文件
    await messageRef.set(messageData);

    // 更新聊天室的最後訊息和時間
    await _firestore.collection('chatRooms').doc(roomId).update({
      'lastMessage': processedText,
      'lastMessageTime': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // 記錄訊息發送事件
    await _securityService.logSecurityEvent(
      'message_sent',
      {
        'userId': currentUserId,
        'roomId': roomId,
        'messageId': messageRef.id,
        'timestamp': now.toIso8601String(),
        'hasBeenProcessed': text != processedText,
      },
    );
  }
  // ===============================================================
  // 根據使用者ID取得聊天使用者資料
  Future<ChatUser?> getChatUserById(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return ChatUser(
        id: userDoc.id,
        name: userDoc.data()?['name'] ?? '',
        email: userDoc.data()?['email'] ?? '',
        photoUrl: userDoc.data()?['photoUrl'] ?? '',
        lastActive: (userDoc.data()?['lastActive'] as Timestamp?)?.toDate(),
      );
    }
    return null;
  }

  // 建立或取得聊天室
  Future<String> createChatRoom({
    required String name,
    String description = '',
    required List<String> participantIds,
    bool isGroupChat = false,
  }) async {
    if (currentUserId == null) throw Exception('未登入');

    // 檢查是否已存在相同參與者的一對一聊天室
    if (!isGroupChat && participantIds.length == 2) {
      final existingRoomQuery = await _firestore
          .collection('chatRooms')
          .where('participantIds', isEqualTo: participantIds)
          .where('isGroupChat', isEqualTo: false)
          .get();

      if (existingRoomQuery.docs.isNotEmpty) {
        return existingRoomQuery.docs.first.id;
      }
    }

    // 建立新聊天室
    final roomRef = _firestore.collection('chatRooms').doc();
    final now = DateTime.now();

    await roomRef.set({
      'name': name,
      'description': description,
      'createdBy': currentUserId,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'lastMessage': '',
      'lastMessageTime': Timestamp.fromDate(now),
      'isGroupChat': isGroupChat,
      'participantIds': participantIds,
    });

    return roomRef.id;
  }

  // 標記訊息為已讀
  void _markMessagesAsRead(String roomId, List<Message> messages) async {
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    bool hasUpdates = false;

    for (final message in messages) {
      // 略過自己發送的訊息和已讀的訊息
      if (message.senderId == currentUserId || message.readBy.contains(currentUserId)) {
        continue;
      }

      // 取得訊息文件參考
      final messageRef = _firestore
          .collection('messages')
          .doc(roomId)
          .collection('chatMessages')
          .doc(message.id);

      // 將當前使用者ID添加到已讀清單
      batch.update(messageRef, {
        'readBy': FieldValue.arrayUnion([currentUserId]),
        'status': 'read',
      });

      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  // 發送圖片訊息 (整合安全處理)
  Future<void> sendImageMessage({
    required String roomId,
    required File imageFile,
  }) async {
    if (currentUserId == null) return;

    // 檢查發送者是否為聊天室成員
    final isAuthorized = await _securityService.isAuthorizedParticipant(
      currentUserId!,
      roomId,
    );

    if (!isAuthorized) {
      await _securityService.logSecurityEvent(
        'unauthorized_image_upload_attempt',
        {
          'userId': currentUserId,
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      throw Exception('您不是此聊天室的成員');
    }

    // 檢查訊息頻率
    final isSpam = await _securityService.isMessageSpam(currentUserId!, roomId);
    if (isSpam) {
      await _securityService.logSecurityEvent(
        'message_spam_detected',
        {
          'userId': currentUserId,
          'roomId': roomId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      throw Exception('訊息發送過於頻繁，請稍後再試');
    }

    // 取得發送者資訊
    final userDoc = await _firestore.collection('users').doc(currentUserId).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final now = DateTime.now();
    final uuid = const Uuid().v4();
    final imageFileName = '$uuid.jpg';

    // 上傳圖片到 Firebase Storage
    final storageRef = _storage.ref().child('chat_images/$roomId/$imageFileName');

    // 記錄圖片上傳開始事件
    await _securityService.logSecurityEvent(
      'image_upload_start',
      {
        'userId': currentUserId,
        'roomId': roomId,
        'fileName': imageFileName,
        'timestamp': now.toIso8601String(),
      },
    );

    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() {});
    final imageUrl = await snapshot.ref.getDownloadURL();

    // 建立訊息文件
    final messageRef = _firestore
        .collection('messages')
        .doc(roomId)
        .collection('chatMessages')
        .doc();

    // 準備訊息資料
    final messageData = {
      'roomId': roomId,
      'senderId': currentUserId,
      'senderName': userData['name'] ?? 'Unknown User',
      'senderPhotoUrl': userData['photoUrl'] ?? '',
      'text': '傳送了一張圖片',
      'timestamp': Timestamp.fromDate(now),
      'type': 'image',
      'imageUrl': imageUrl,
      'status': 'sent',
      'readBy': [currentUserId],
    };

    // 產生訊息哈希值
    final message = Message(
      id: messageRef.id,
      roomId: roomId,
      senderId: currentUserId!,
      senderName: userData['name'] ?? 'Unknown User',
      senderPhotoUrl: userData['photoUrl'] ?? '',
      text: '傳送了一張圖片',
      timestamp: now,
      type: MessageType.image,
      status: MessageStatus.sent,
      readBy: [currentUserId!],
      imageUrl: imageUrl,
    );

    final messageHash = _securityService.generateMessageHash(message);

    // 添加哈希值到訊息資料
    messageData['hash'] = messageHash;

    // 儲存訊息文件
    await messageRef.set(messageData);

    // 更新聊天室的最後訊息和時間
    await _firestore.collection('chatRooms').doc(roomId).update({
      'lastMessage': '傳送了一張圖片',
      'lastMessageTime': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // 記錄圖片上傳完成事件
    await _securityService.logSecurityEvent(
      'image_upload_complete',
      {
        'userId': currentUserId,
        'roomId': roomId,
        'messageId': messageRef.id,
        'fileName': imageFileName,
        'timestamp': now.toIso8601String(),
      },
    );
  }

  // 取得使用者的所有聊天室
  Stream<List<ChatRoom>> getUserChatRooms() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoom.fromFirestore(doc))
          .toList();
    });
  }

  // 取得聊天室訊息 (整合安全驗證)
  Stream<List<Message>> getChatMessages(String roomId) {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('messages')
        .doc(roomId)
        .collection('chatMessages')
        .orderBy('timestamp', descending: true)
        .limit(50)  // 限制載入的訊息數量
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = snapshot.docs
          .map((doc) {
        final message = Message.fromFirestore(doc);

        // 驗證訊息完整性
        final storedHash = doc.data()['hash'] as String?;
        if (storedHash != null) {
          final isValid = _securityService.verifyMessageIntegrity(
            message,
            storedHash,
          );

          if (!isValid) {
            // 記錄訊息完整性驗證失敗
            _securityService.logSecurityEvent(
              'message_integrity_verification_failed',
              {
                'userId': currentUserId,
                'roomId': roomId,
                'messageId': message.id,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );

            // 返回警告訊息
            return message.copyWith(
              text: '[此訊息可能已被篡改]',
              type: MessageType.text,
            );
          }
        }

        // 處理原始文字 (僅發送者可以看到)
        final originalText = doc.data()['originalText'] as String?;
        if (originalText != null && message.senderId == currentUserId) {
          return message.copyWith(text: originalText);
        }

        return message;
      })
          .toList();

      // 如果目前使用者已登入，更新尚未標記為已讀的訊息
      if (currentUserId != null) {
        _markMessagesAsRead(roomId, messages);
      }

      return messages;
    });
  }
}