import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file }
enum MessageStatus { sending, sent, delivered, read }

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;
  final List<String> readBy;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    required this.type,
    required this.status,
    required this.readBy,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
  });

  // 從 Firestore 資料轉換成模型
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // 解析訊息類型
    MessageType messageType;
    switch (data['type']) {
      case 'image':
        messageType = MessageType.image;
        break;
      case 'file':
        messageType = MessageType.file;
        break;
      default:
        messageType = MessageType.text;
    }

    // 解析訊息狀態
    MessageStatus messageStatus;
    switch (data['status']) {
      case 'sent':
        messageStatus = MessageStatus.sent;
        break;
      case 'delivered':
        messageStatus = MessageStatus.delivered;
        break;
      case 'read':
        messageStatus = MessageStatus.read;
        break;
      default:
        messageStatus = MessageStatus.sending;
    }

    return Message(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: messageType,
      status: messageStatus,
      readBy: List<String>.from(data['readBy'] ?? []),
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
    );
  }

  // 轉換成 Firestore 資料格式
  Map<String, dynamic> toFirestore() {
    String typeString;
    switch (type) {
      case MessageType.image:
        typeString = 'image';
        break;
      case MessageType.file:
        typeString = 'file';
        break;
      default:
        typeString = 'text';
    }

    String statusString;
    switch (status) {
      case MessageStatus.sent:
        statusString = 'sent';
        break;
      case MessageStatus.delivered:
        statusString = 'delivered';
        break;
      case MessageStatus.read:
        statusString = 'read';
        break;
      default:
        statusString = 'sending';
    }

    return {
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': typeString,
      'status': statusString,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
    };
  }

  // 建立訊息發送中的實例
  factory Message.sending({
    required String roomId,
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String text,
    MessageType type = MessageType.text,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      timestamp: DateTime.now(),
      type: type,
      status: MessageStatus.sending,
      readBy: [],
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
    );
  }

  // 複製消息並更新狀態
  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? text,
    DateTime? timestamp,
    MessageType? type,
    MessageStatus? status,
    List<String>? readBy,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl ?? this.imageUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
    );
  }
}