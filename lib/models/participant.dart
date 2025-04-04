import 'package:cloud_firestore/cloud_firestore.dart';

enum ParticipantRole { admin, member }

class Participant {
  final String userId;
  final DateTime joinedAt;
  final ParticipantRole role;

  Participant({
    required this.userId,
    required this.joinedAt,
    required this.role,
  });

  // 從 Firestore 資料轉換成模型
  factory Participant.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    ParticipantRole role = data['role'] == 'admin'
        ? ParticipantRole.admin
        : ParticipantRole.member;

    return Participant(
      userId: data['userId'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      role: role,
    );
  }

  // 轉換成 Firestore 資料格式
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'role': role == ParticipantRole.admin ? 'admin' : 'member',
    };
  }
}