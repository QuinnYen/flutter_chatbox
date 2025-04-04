import 'package:cloud_firestore/cloud_firestore.dart';

class ChatUser {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final DateTime? lastActive;

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    this.lastActive,
  });

  // 從 Firestore 資料轉換成模型
  factory ChatUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return ChatUser(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
    );
  }
}