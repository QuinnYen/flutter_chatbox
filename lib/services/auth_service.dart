import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 取得目前使用者
  User? get currentUser => _auth.currentUser;

  // 監聽使用者狀態變化的串流
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 使用電子郵件和密碼註冊
  Future<UserCredential> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    UserCredential? userCredential;
    try {
      // 創建新使用者
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 在 Firestore 中儲存使用者資料
      if (userCredential.user != null) {
        try {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'name': name,
            'email': email,
            'photoUrl': '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });

          // 更新使用者顯示名稱
          await userCredential.user!.updateDisplayName(name);
        } catch (firestoreError) {
          // 若寫入 Firestore 失敗，記錄但繼續流程
          print('Firestore 寫入錯誤: $firestoreError');
          // 不拋出異常，讓用戶仍能登入
        }
      }

      return userCredential;
    } catch (e) {
      // 如果創建了用戶但後續步驟失敗，嘗試登入而非報錯
      if (userCredential?.user != null) {
        print('註冊部分成功，嘗試直接登入');
        return userCredential!;
      }
      throw '註冊時發生錯誤：$e';
    }
  }

  // 使用電子郵件和密碼登入
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // 登入使用者
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 更新使用者最後活動時間
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // 處理常見的登入錯誤
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '找不到此電子郵件的使用者';
          break;
        case 'wrong-password':
          errorMessage = '密碼錯誤';
          break;
        case 'invalid-email':
          errorMessage = '無效的電子郵件格式';
          break;
        case 'user-disabled':
          errorMessage = '此帳號已被停用';
          break;
        default:
          errorMessage = '登入時發生錯誤：${e.message}';
      }

      throw errorMessage;
    } catch (e) {
      throw '登入時發生未知錯誤：$e';
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      // 更新使用者最後活動時間
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
    } catch (e) {
      throw '登出時發生錯誤：$e';
    }
  }

  // 密碼重設
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '找不到此電子郵件的使用者';
          break;
        case 'invalid-email':
          errorMessage = '無效的電子郵件格式';
          break;
        default:
          errorMessage = '重設密碼時發生錯誤：${e.message}';
      }

      throw errorMessage;
    } catch (e) {
      throw '重設密碼時發生未知錯誤：$e';
    }
  }
}