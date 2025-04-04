import 'package:flutter/material.dart';
import 'package:flutter_chatbox/screens/auth/auth_wrapper.dart';
import 'package:flutter_chatbox/screens/auth/login_screen.dart';
import 'package:flutter_chatbox/screens/auth/register_screen.dart';
import 'package:flutter_chatbox/screens/chat/chat_list_screen.dart';
import 'package:flutter_chatbox/screens/chat/chat_room_screen.dart';
import 'package:flutter_chatbox/screens/home_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String chatList = '/chat-list';
  static const String chatRoom = '/chat-room';
  static const String authWrapper = '/auth-wrapper';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      home: (context) => const HomeScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      chatList: (context) => const ChatListScreen(),
      authWrapper: (context) => const AuthWrapper(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == chatRoom) {
      final args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          roomId: args['roomId'],
          roomName: args['roomName'],
        ),
      );
    }
    return null;
  }
}