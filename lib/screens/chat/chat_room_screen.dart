import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chatbox/models/message.dart';
import 'package:flutter_chatbox/providers/auth_provider.dart';
import 'package:flutter_chatbox/providers/chat_provider.dart';
import 'package:flutter_chatbox/services/chat_service.dart';
import 'package:flutter_chatbox/widgets/chat_bubble.dart';
import 'package:flutter_chatbox/widgets/date_separator.dart';
import 'package:flutter_chatbox/widgets/message_input.dart';
import 'package:flutter_chatbox/models/chat_room.dart';
import 'package:provider/provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  @override
  void initState() {
    super.initState();

    // 設定當前聊天室
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.setCurrentRoom(widget.roomId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showChatInfo(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 錯誤訊息顯示
          if (chatProvider.hasError)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[100],
              width: double.infinity,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () {
                      chatProvider.clearError();
                    },
                  ),
                ],
              ),
            ),

          // 聊天訊息列表
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: chatProvider.loadMessages(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('發生錯誤: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // 重新載入
                          },
                          child: const Text('重試'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('開始發送訊息吧！', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,  // 最新的訊息在底部
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.senderId == currentUserId;

                    // 顯示日期分隔線
                    final bool showDate = index == messages.length - 1 ||
                        !_isSameDay(messages[index].timestamp, messages[index + 1].timestamp);

                    return Column(
                      children: [
                        if (showDate)
                          DateSeparator(date: message.timestamp),
                        ChatBubble(
                          message: message,
                          isMe: isMe,
                          onImageTap: message.type == MessageType.image && message.imageUrl != null
                              ? () => _showFullScreenImage(context, message.imageUrl!)
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // 訊息輸入框
          MessageInput(
            controller: _messageController,
            isLoading: chatProvider.isLoading,
            onSendText: () {
              _sendMessage(chatProvider);
            },
            onSendImage: (File imageFile) async {
              await _sendImage(chatProvider, imageFile);
            },
          ),
        ],
      ),
    );
  }

  // 發送文字訊息
  Future<void> _sendMessage(ChatProvider chatProvider) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await chatProvider.sendTextMessage(widget.roomId, text);
    } catch (e) {
      // 錯誤處理已在 Provider 中完成
    }
  }

  // 發送圖片
  Future<void> _sendImage(ChatProvider chatProvider, File imageFile) async {
    try {
      await chatProvider.sendImageMessage(widget.roomId, imageFile);
    } catch (e) {
      // 錯誤處理已在 Provider 中完成
    }
  }

  // 顯示聊天室資訊
  Future<void> _showChatInfo(BuildContext context) async {
    final participants = await _chatService.getChatRoomParticipants(widget.roomId);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: FutureBuilder<ChatRoom?>(
                          future: _chatService.getChatRoom(widget.roomId).first,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final isGroupChat = snapshot.data!.isGroupChat;
                              return Icon(
                                isGroupChat ? Icons.group : Icons.person,
                                color: Colors.white,
                              );
                            }
                            // 預設顯示
                            return const Icon(Icons.person, color: Colors.white);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.roomName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FutureBuilder<Object?>(
                              future: _chatService.getChatRoom(widget.roomId).first,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final room = snapshot.data as dynamic;
                                  return Text(
                                    room.isGroupChat
                                        ? '群組聊天 · ${participants.length} 位成員'
                                        : '私人聊天',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  // 聊天成員
                  const Text(
                    '聊天成員',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final participant = participants[index];
                        final isCurrentUser = participant.id == Provider.of<AuthProvider>(context).firebaseUser?.uid;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: participant.photoUrl.isNotEmpty
                                ? NetworkImage(participant.photoUrl)
                                : null,
                            child: participant.photoUrl.isEmpty
                                ? Text(participant.name.substring(0, 1).toUpperCase())
                                : null,
                          ),
                          title: Row(
                            children: [
                              Text(participant.name),
                              if (isCurrentUser)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '我',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(participant.email),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 顯示全螢幕圖片
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 3,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.error, color: Colors.red, size: 50),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 檢查兩個日期是否在同一天
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}