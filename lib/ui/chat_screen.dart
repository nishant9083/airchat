import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late Box<ChatUser> _userBox;
  bool _autoConnectTried = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<ChatUser>('chat_users');
    // Mark all as read on open
    final user = _userBox.get(widget.userId);
    if (user != null) {
      for (var msg in user.messages) {
        if (!msg.isMe && !msg.isRead) {
          msg.isRead = true;
        }
      }
      user.save();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = _userBox.get(widget.userId);
    if (user == null) return;

    final msg = ChatMessage(
      senderId: 'me',
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
      isRead: true,
    );

    _controller.clear();
    user.messages.add(msg);
    user.save();
    await ConnectionService.sendMessage(user.id, text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionStateProvider>(
      builder: (context, connProvider, _) {
        // Determine status
        String statusText;
        Color statusColor;
        final isConnected = connProvider.connected.contains(widget.userId);
        final isConnecting = connProvider.connecting.contains(widget.userId);
        final isAvailable = connProvider.discovered.containsKey(widget.userId);
        if (isConnected) {
          statusText = 'Connected';
          statusColor = Colors.green;
        } else if (isConnecting) {
          statusText = 'Connecting...';
          statusColor = Colors.orange;
        } else if (isAvailable) {
          statusText = 'Available';
          statusColor = Colors.blue;
        } else {
          statusText = 'Not Available';
          statusColor = Colors.grey;
        }

        // Auto-connect if not connected and available
        if (!_autoConnectTried && !isConnected && isAvailable) {
          _autoConnectTried = true;
          Future.microtask(
                  () => ConnectionService.connectToDevice(widget.userId));
        }

        return Scaffold(
          appBar: AppBar(
            title: ValueListenableBuilder(
              valueListenable: _userBox.listenable(),
              builder: (context, Box<ChatUser> box, _) {
                final user = box.get(widget.userId);
                return Text(user?.name ?? 'Unknown');
              },
            ),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: statusColor.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: statusColor, size: 12),
                    const SizedBox(width: 8),
                    Text(statusText,
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: _userBox.listenable(),
                  builder: (context, Box<ChatUser> box, _) {
                    final user = box.get(widget.userId);
                    if (user == null) {
                      return const Center(child: Text('User not found'));
                    }
                    // Scroll to bottom when new messages are added
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: user.messages.length,
                      itemBuilder: (context, index) {
                        final msg = user.messages[index];
                        return Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: msg.isMe
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                color: msg.isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        enabled: isConnected,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isConnected ? _sendMessage : null,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Icon(Icons.send, color: Colors.white,),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
