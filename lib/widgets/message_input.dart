import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final Function() onSendText;
  final Function(File imageFile) onSendImage;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.isLoading,
    required this.onSendText,
    required this.onSendImage,
  }) : super(key: key);

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateComposingState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateComposingState);
    super.dispose();
  }

  void _updateComposingState() {
    final isComposing = widget.controller.text.isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      widget.onSendImage(File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo),
            color: Colors.blue,
            onPressed: widget.isLoading ? null : _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              decoration: const InputDecoration(
                hintText: '輸入訊息...',
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (_isComposing && !widget.isLoading) {
                  widget.onSendText();
                }
              },
              enabled: !widget.isLoading,
            ),
          ),
          IconButton(
            icon: widget.isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Icon(
              Icons.send,
              color: _isComposing ? Colors.blue : Colors.grey,
            ),
            onPressed: (_isComposing && !widget.isLoading) ? widget.onSendText : null,
          ),
        ],
      ),
    );
  }
}