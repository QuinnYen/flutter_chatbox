import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chatbox/models/user.dart';
import 'package:flutter_chatbox/services/auth_service.dart';
import 'package:flutter_chatbox/services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;

  // 取得目前的 Firebase 使用者
  User? get firebaseUser => _firebaseUser;

  // 取得使用者資料模型
  UserModel? get userModel => _userModel;

  // 使用者是否已登入
  bool get isAuthenticated => _firebaseUser != null;

  // 是否正在載入
  bool get isLoading => _isLoading;

  AuthProvider() {
    // 初始化時監聽使用者登入狀態變化
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // 處理登入狀態變化
  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user != null) {
      // 使用者已登入，載入使用者資料
      _userModel = await _userService.getUserById(user.uid);
    } else {
      // 使用者已登出，清除使用者資料
      _userModel = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // 使用電子郵件和密碼登入
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 使用電子郵件和密碼註冊
  Future<void> registerWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.registerWithEmailAndPassword(
        name: name,
        email: email,
        password: password,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 登出
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 更新使用者資料
  Future<void> updateUserInfo({
    String? name,
    String? photoUrl,
  }) async {
    if (_firebaseUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _userService.updateUserInfo(
        uid: _firebaseUser!.uid,
        name: name,
        photoUrl: photoUrl,
      );

      // 重新載入使用者資料
      _userModel = await _userService.getUserById(_firebaseUser!.uid);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}