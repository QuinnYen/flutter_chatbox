import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chatbox/models/user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 取得目前登入使用者的資料
  Future<UserModel?> getCurrentUser() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
    }

    return null;
  }

  // 根據使用者ID取得使用者資料
  Future<UserModel?> getUserById(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
    }

    return null;
  }

  // 更新使用者資料
  Future<void> updateUserInfo({
    required String uid,
    String? name,
    String? photoUrl,
  }) async {
    Map<String, dynamic> data = {};

    if (name != null && name.isNotEmpty) {
      data['name'] = name;
    }

    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }

    if (data.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(data);

      // 如果是當前使用者，同時更新 Firebase Auth 的使用者資料
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        if (name != null && name.isNotEmpty) {
          await currentUser.updateDisplayName(name);
        }

        if (photoUrl != null && photoUrl.isNotEmpty) {
          await currentUser.updatePhotoURL(photoUrl);
        }
      }
    }
  }

  // 取得所有使用者列表
  Future<List<UserModel>> getAllUsers() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();

    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // 搜尋使用者
  Future<List<UserModel>> searchUsers(String keyword) async {
    // 實作簡單的使用者搜尋功能，根據名稱或電子郵件
    QuerySnapshot snapshot = await _firestore.collection('users')
        .where('name', isGreaterThanOrEqualTo: keyword)
        .where('name', isLessThanOrEqualTo: keyword + '\uf8ff')
        .get();

    List<UserModel> users = snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList();

    // 根據電子郵件搜尋
    QuerySnapshot emailSnapshot = await _firestore.collection('users')
        .where('email', isGreaterThanOrEqualTo: keyword)
        .where('email', isLessThanOrEqualTo: keyword + '\uf8ff')
        .get();

    // 合併結果並去除重複
    for (var doc in emailSnapshot.docs) {
      UserModel user = UserModel.fromFirestore(doc.data() as Map<String, dynamic>);
      if (!users.any((u) => u.uid == user.uid)) {
        users.add(user);
      }
    }

    return users;
  }
}