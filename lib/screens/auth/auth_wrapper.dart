import 'package:flutter/material.dart';
import 'package:flutter_chatbox/providers/auth_provider.dart';
import 'package:flutter_chatbox/screens/auth/login_screen.dart';
import 'package:flutter_chatbox/screens/chat/chat_list_screen.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // 顯示載入中畫面
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 根據登入狀態導向不同的頁面
    if (authProvider.isAuthenticated) {
      return const ChatListScreen();
    } else {
      return const LoginScreen();
    }
  }
}