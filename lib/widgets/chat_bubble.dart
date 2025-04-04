import 'package:flutter/material.dart';
import 'package:flutter_chatbox/models/message.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onImageTap;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.timestamp);

    // 確定訊息狀態圖示
    Widget? statusIcon;
    if (isMe) {
      switch (message.status) {
        case MessageStatus.sending:
          statusIcon = const Icon(Icons.access_time, size: 12, color: Colors.grey);
          break;
        case MessageStatus.sent:
          statusIcon = const Icon(Icons.check, size: 12, color: Colors.grey);
          break;
        case MessageStatus.delivered:
          statusIcon = const Icon(Icons.done_all, size: 12, color: Colors.grey);
          break;
        case MessageStatus.read:
          statusIcon = const Icon(Icons.done_all, size: 12, color: Colors.blue);
          break;
      }
    }

    // 建立訊息氣泡
    Widget messageBubble;

    switch (message.type) {
      case MessageType.image:
        messageBubble = GestureDetector(
          onTap: onImageTap,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
              maxHeight: 200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: message.imageUrl != null
                  ? Image.network(
                message.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 150,
                    color: Colors.grey[300],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 150,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  );
                },
              )
                  : Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: const Center(
                  child: Text('圖片不可用'),
                ),
              ),
            ),
          ),
        );
        break;

      case MessageType.file:
        messageBubble = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                color: isMe ? Colors.white : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                message.fileName ?? '檔案',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        );
        break;

      case MessageType.text:
      default:
        messageBubble = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black,
            ),
          ),
        );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // 如果不是自己發的，顯示發送者名稱
            if (!isMe && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),

            // 訊息氣泡
            messageBubble,

            // 時間和狀態
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  if (statusIcon != null) ...[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}