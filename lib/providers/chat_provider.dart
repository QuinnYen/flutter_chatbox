import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chatbox/models/chat_room.dart';
import 'package:flutter_chatbox/models/message.dart';
import 'package:flutter_chatbox/services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  String? _currentRoomId;
  List<Message> _messages = [];
  List<ChatRoom> _chatRooms = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // 取得當前聊天室 ID
  String? get currentRoomId => _currentRoomId;

  // 取得訊息列表
  List<Message> get messages => _messages;

  // 取得聊天室列表
  List<ChatRoom> get chatRooms => _chatRooms;

  // 是否正在載入
  bool get isLoading => _isLoading;

  // 是否有錯誤
  bool get hasError => _hasError;

  // 錯誤訊息
  String get errorMessage => _errorMessage;

  // 設定當前聊天室
  void setCurrentRoom(String roomId) {
    _currentRoomId = roomId;
    notifyListeners();
  }

  // 載入聊天室訊息
  Stream<List<Message>> loadMessages(String roomId) {
    setCurrentRoom(roomId);

    return _chatService.getChatMessages(roomId)
        .map((messages) {
      _messages = messages;
      return messages;
    });
  }

  // 發送文字訊息
  Future<void> sendTextMessage(String roomId, String text) async {
    if (text.trim().isEmpty) return;

    try {
      _setLoading(true);

      // 發送訊息
      await _chatService.sendTextMessage(
        roomId: roomId,
        text: text,
      );

    } catch (e) {
      _setError('發送訊息失敗: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 發送圖片訊息
  Future<void> sendImageMessage(String roomId, File imageFile) async {
    try {
      _setLoading(true);

      // 發送圖片
      await _chatService.sendImageMessage(
        roomId: roomId,
        imageFile: imageFile,
      );

    } catch (e) {
      _setError('發送圖片失敗: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 載入聊天室列表
  Stream<List<ChatRoom>> loadChatRooms() {
    return _chatService.getUserChatRooms()
        .map((rooms) {
      _chatRooms = rooms;
      return rooms;
    });
  }

  // 建立新聊天室
  Future<String> createChatRoom({
    required String name,
    String description = '',
    required List<String> participantIds,
    bool isGroupChat = false,
  }) async {
    try {
      _setLoading(true);

      final roomId = await _chatService.createChatRoom(
        name: name,
        description: description,
        participantIds: participantIds,
        isGroupChat: isGroupChat,
      );

      return roomId;
    } catch (e) {
      _setError('建立聊天室失敗: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // 設定載入狀態
  void _setLoading(bool loading) {
    _isLoading = loading;

    if (loading) {
      _hasError = false;
      _errorMessage = '';
    }

    notifyListeners();
  }

  // 設定錯誤狀態
  void _setError(String message) {
    _hasError = true;
    _errorMessage = message;
    notifyListeners();
  }

  // 清除錯誤狀態
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}