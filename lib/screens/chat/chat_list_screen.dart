import 'package:flutter/material.dart';
import 'package:flutter_chatbox/models/chat_room.dart';
import 'package:flutter_chatbox/models/chat_user.dart';
import 'package:flutter_chatbox/providers/auth_provider.dart';
import 'package:flutter_chatbox/services/chat_service.dart';
import 'package:flutter_chatbox/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 儲存導航路徑
              final navigateTo = '/';
              await authProvider.signOut();
              // 檢查當前頁面是否還存在於導航樹中
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, navigateTo);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: _chatService.getUserChatRooms(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('發生錯誤: ${snapshot.error}'),
            );
          }

          final chatRooms = snapshot.data ?? [];

          if (chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('尚無聊天室', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('開始聊天'),
                    onPressed: () {
                      _showSearchDialog(context);
                    },
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              return _buildChatRoomItem(context, chatRoom);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showSearchDialog(context);
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildChatRoomItem(BuildContext context, ChatRoom chatRoom) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;

    // 解析最後訊息時間
    final lastMessageTime = chatRoom.lastMessageTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(lastMessageTime.year, lastMessageTime.month, lastMessageTime.day);

    String formattedTime;
    if (messageDate == today) {
      // 今天的訊息，只顯示時間
      formattedTime = DateFormat('HH:mm').format(lastMessageTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // 昨天的訊息
      formattedTime = '昨天';
    } else if (now.difference(lastMessageTime).inDays < 7) {
      // 一週內的訊息，顯示星期
      formattedTime = DateFormat('EEEE', 'zh_TW').format(lastMessageTime);
    } else {
      // 更早的訊息，顯示日期
      formattedTime = DateFormat('yyyy/MM/dd').format(lastMessageTime);
    }

    // 決定顯示的聊天室名稱
    String displayName = chatRoom.name;

    // 一對一聊天室，顯示對方的名稱
    if (!chatRoom.isGroupChat && chatRoom.participantIds.length == 2) {
      // 找出對方的ID
      final otherUserId = chatRoom.participantIds.firstWhere(
            (id) => id != currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty) {
        // 非同步獲取對方的名稱，使用 FutureBuilder
        return FutureBuilder<ChatUser?>(
          future: _chatService.getChatUserById(otherUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: const CircleAvatar(child: CircularProgressIndicator()),
                title: Text(displayName),
                subtitle: Text(chatRoom.lastMessage),
                trailing: Text(formattedTime),
              );
            }

            if (snapshot.hasData && snapshot.data != null) {
              displayName = snapshot.data!.name;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: snapshot.data!.photoUrl.isNotEmpty
                      ? NetworkImage(snapshot.data!.photoUrl)
                      : null,
                  child: snapshot.data!.photoUrl.isEmpty
                      ? Text(displayName.substring(0, 1).toUpperCase())
                      : null,
                ),
                title: Text(displayName),
                subtitle: Text(
                  chatRoom.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(formattedTime),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/chat-room',
                    arguments: {
                      'roomId': chatRoom.id,
                      'roomName': displayName,
                    },
                  );
                },
              );
            }

            // 找不到使用者資料，顯示預設值
            return ListTile(
              leading: CircleAvatar(
                child: Text(displayName.substring(0, 1).toUpperCase()),
              ),
              title: Text(displayName),
              subtitle: Text(
                chatRoom.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(formattedTime),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chat-room',
                  arguments: {
                    'roomId': chatRoom.id,
                    'roomName': displayName,
                  },
                );
              },
            );
          },
        );
      }
    }

    // 群組聊天室或其他情況，直接顯示聊天室名稱
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: chatRoom.isGroupChat ? Colors.teal : Colors.blue,
        child: chatRoom.isGroupChat
            ? const Icon(Icons.group, color: Colors.white)
            : Text(displayName.substring(0, 1).toUpperCase()),
      ),
      title: Text(displayName),
      subtitle: Text(
        chatRoom.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(formattedTime),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/chat-room',
          arguments: {
            'roomId': chatRoom.id,
            'roomName': displayName,
          },
        );
      },
    );
  }

  // 顯示搜尋對話框，用於搜尋使用者並創建聊天室
  Future<void> _showSearchDialog(BuildContext context) async {
    final TextEditingController searchController = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    if (currentUserId == null) return;

    List<ChatUser> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('尋找聊天對象'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: '輸入使用者名稱或電子郵件',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          isSearching = true;
                        });

                        try {
                          final results = await _userService.searchUsers(value.trim());
                          // 過濾掉目前使用者並轉換類型
                          searchResults = results
                              .where((user) => user.uid != currentUserId)
                              .map((user) => ChatUser(
                            id: user.uid,
                            name: user.name,
                            email: user.email,
                            photoUrl: user.photoUrl,
                            lastActive: user.lastActive,
                          ))
                              .toList();
                        } finally {
                          setState(() {
                            isSearching = false;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    const CircularProgressIndicator()
                  else if (searchResults.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? NetworkImage(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? Text(user.name.substring(0, 1).toUpperCase())
                                  : null,
                            ),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                            onTap: () async {
                              Navigator.of(context).pop();

                              // 創建或獲取聊天室
                              final roomId = await _chatService.createChatRoom(
                                name: '${authProvider.userModel?.name} 與 ${user.name}',
                                participantIds: [currentUserId, user.id],
                                isGroupChat: false,
                              );

                              // 添加此檢查
                              if (context.mounted) {
                                // 導航到聊天室頁面
                                Navigator.pushNamed(
                                  context,
                                  '/chat-room',
                                  arguments: {
                                    'roomId': roomId,
                                    'roomName': user.name,
                                  },
                                );
                              }
                            },
                          );
                        },
                      ),
                    )
                  else if (searchController.text.isNotEmpty)
                      const Text('找不到符合的使用者'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final value = searchController.text.trim();
                    if (value.isNotEmpty) {
                      setState(() {
                        isSearching = true;
                      });

                      try {
                        final results = await _userService.searchUsers(value);
                        // 過濾掉目前使用者並轉換類型
                        searchResults = results
                            .where((user) => user.uid != currentUserId)
                            .map((user) => ChatUser(
                          id: user.uid,
                          name: user.name,
                          email: user.email,
                          photoUrl: user.photoUrl,
                          lastActive: user.lastActive,
                        ))
                            .toList();
                      } finally {
                        setState(() {
                          isSearching = false;
                        });
                      }
                    }
                  },
                  child: const Text('搜尋'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}