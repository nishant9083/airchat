import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:airchat/services/overlay_service.dart';
import 'package:airchat/ui/calling_screen.dart';
import 'package:airchat/utility/image_viewer.dart';
import 'package:airchat/utility/audio_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';
import '../providers/call_state_provider.dart';
import 'package:open_file/open_file.dart';
import '../widgets/chat_screen_helpers.dart';
import '../utility/media_selection.dart';

import '../utility/snackbar_util.dart';
import '../utility/video_viewer.dart';

class ChatScreen extends StatefulWidget {
  final ChatUser user;
  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late Box<ChatUser> _userBox;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _fileTransferProgressSubscription;
  final Map<int, ChatMessage> _selectedMessages = {};
  bool get _isSelectionMode => _selectedMessages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<ChatUser>('chat_users');
    // Mark all as read on open
    final user = _userBox.get(widget.user.id);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ConnectionService.fileTransferProgressStream.listen((event) {
      final payloadId = event['id'];
      final progress = event['progress'];
      // Find the message being sent/received (by filePath or other means)
      final user = _userBox.get(widget.user.id);
      if (user != null) {
        try {
          final msg = user.messages.firstWhere((m) => m.id == payloadId);
          msg.transferProgress = progress;
          msg.status = event['status'];
          user.save();
        } catch (e) {
          log('Error finding message for payload $payloadId: $e');
        }
      }
    });
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
    _fileTransferProgressSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void showSnackbar(String message) {
    SnackbarUtil.show(context, message: message);
  }

  void _sendMessage() async {
    try {
      final text = _controller.text.trim();
      if (text.isEmpty) return;

      final user = _userBox.get(widget.user.id);
      if (user == null) return;

      final id = DateTime.now().toIso8601String();
      final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'text');

      _controller.clear();
      user.messages.add(msg);
      user.save();
      await ConnectionService.sendMessage(id, user.id, text, 'message');
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      showSnackbar('Failed to send message: $e');
    }
  }

  Future<void> onAudioRecordingComplete(
    String filePath,
    String fileName,
  ) async {
    try {
      final user = _userBox.get(widget.user.id);
      if (user == null) return;

      String id = DateTime.now().toIso8601String();
      final msg = ChatMessage(
        id: id,
        senderId: 'me',
        text: '',
        timestamp: DateTime.now(),
        isMe: true,
        isRead: true,
        type: 'audio',
        fileName: fileName,
        filePath: filePath,
        mimeType: 'audio/m4a',
      );

      user.messages.add(msg);
      user.save();
      await ConnectionService.sendFile(id, widget.user.id, filePath, fileName);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (kDebugMode) {
        print('Error sending audio recording: $e');
      }
      showSnackbar('Failed to send audio recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionStateProvider, CallStateProvider>(
      builder: (context, connProvider, callProvider, _) {
        // Determine status
        String statusText;
        Color statusColor;
        final isConnected =
            connProvider.connectedPeers.any((p) => p.userId == widget.user.id);
        if (isConnected) {
          statusText = 'Connected';
          statusColor = Colors.green;
        } else {
          statusText = 'Not Available';
          statusColor = Colors.grey;
        }
        final colorScheme = Theme.of(context).colorScheme;
        // Main UI
        return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, _) async {
              if (didPop) {
                return;
              }
              if (_isSelectionMode) {
                setState(() {
                  _selectedMessages.clear();
                });
                return;
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Scaffold(
              appBar: _isSelectionMode
                  ? AppBar(
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _selectedMessages.clear()),
                      ),
                      title: Text('${_selectedMessages.length}'),
                      actions: [
                          if (_selectedMessages.length == 1 &&
                              _selectedMessages.entries.first.value.type ==
                                  'text')
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(
                                    text: _selectedMessages
                                        .entries.first.value.text));
                                showSnackbar('Message copied');
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              final messagesToDelete =
                                  _selectedMessages.values.toList();

                              // Check if any selected message contains media (file, image, audio, video)
                              bool containsMedia = messagesToDelete.any((msg) =>
                                  msg.type == 'image' ||
                                  msg.type == 'file' ||
                                  msg.type == 'audio' ||
                                  msg.type == 'video');

                              // Show dialog
                              if (messagesToDelete.isEmpty) return;
                              if (!containsMedia) {
                                // Only text messages, simple confirm dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      'Delete${_selectedMessages.length > 1 ? ' ${_selectedMessages.length}' : ''} message${_selectedMessages.length > 1 ? 's' : ''}?',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                              color: colorScheme.onTertiary),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await deleteMessages(
                                              deleteMedia: false,
                                              messagesToDelete:
                                                  messagesToDelete,
                                              user: widget.user);
                                          setState(() {
                                            _selectedMessages.clear();
                                          });
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Contains media, ask if want to delete from storage too
                                bool deleteMediaFromStorage = false;
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setState) =>
                                          AlertDialog(
                                        title: Text(
                                          'Delete${_selectedMessages.length > 1 ? ' ${_selectedMessages.length}' : ''} message${_selectedMessages.length > 1 ? 's' : ''}?',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CheckboxListTile(
                                                value: deleteMediaFromStorage,
                                                onChanged: (val) {
                                                  setState(() {
                                                    deleteMediaFromStorage =
                                                        val ?? false;
                                                  });
                                                },
                                                title: const Text(
                                                    'Delete media from device'),
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                                side: BorderSide(
                                                    color: colorScheme
                                                        .onTertiary)),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                  color:
                                                      colorScheme.onTertiary),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await deleteMessages(
                                                  deleteMedia:
                                                      deleteMediaFromStorage,
                                                  messagesToDelete:
                                                      messagesToDelete,
                                                  user: widget.user);
                                              setState(() {
                                                _selectedMessages.clear();
                                              });
                                            },
                                            child: const Text(
                                              'Delete',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward),
                            onPressed: () {
                              // Forward logic for selected messages
                              showSnackbar('Not implemented');
                            },
                          ),
                        ])
                  : AppBar(
                      elevation: 10,
                      title: ValueListenableBuilder(
                        valueListenable: _userBox.listenable(),
                        builder: (context, Box<ChatUser> box, _) {
                          final user = box.get(widget.user.id);
                          return Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.name ?? 'Unknown'),
                                Text(statusText,
                                    style: TextStyle(
                                        color: statusColor, fontSize: 12)),
                              ]);
                        },
                      ),
                      actions: [
                        Consumer2<ConnectionStateProvider, CallStateProvider>(
                          builder: (context, connProvider, callProvider, _) {
                            final isConnected = connProvider.connectedPeers
                                .any((p) => p.userId == widget.user.id);
                            return IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: isConnected
                                  ? () async {
                                      try {
                                        final id =
                                            DateTime.now().toIso8601String();
                                        callProvider.startOutgoingCall(
                                            widget.user.id, id);
                                        await ConnectionService.sendCallInvite(
                                            widget.user.id, id);
                                        if (Platform.isAndroid ||
                                            Platform.isIOS) {
                                          if (context.mounted) {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => CallScreen(
                                                    user: widget.user),
                                              ),
                                            );
                                          }
                                        } else {
                                          DraggableOverlayService()
                                              .showOverlay(widget.user);
                                        }
                                      } on Exception catch (e) {
                                        showSnackbar(e.toString());
                                      }
                                    }
                                  : () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'User not available for call')),
                                      );
                                    },
                              tooltip: 'Voice Call',
                            );
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'More options',
                          onSelected: (value) {
                            if (value == 'mute') {
                              showSnackbar(
                                  'Mute notifications not implemented');
                            } else if (value == 'clear') {
                              bool deleteMediaFromStorage = false;

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (context, setState) => AlertDialog(
                                      title: Text(
                                        'Delete${widget.user.messages.length > 1 ? ' ${widget.user.messages.length}' : ''} message${widget.user.messages.length > 1 ? 's' : ''}?',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CheckboxListTile(
                                              value: deleteMediaFromStorage,
                                              onChanged: (val) {
                                                setState(() {
                                                  deleteMediaFromStorage =
                                                      val ?? false;
                                                });
                                              },
                                              title: const Text(
                                                  'Delete media from device'),
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                              side: BorderSide(
                                                  color:
                                                      colorScheme.onTertiary)),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                                color: colorScheme.onTertiary),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            await deleteMessages(
                                                deleteMedia:
                                                    deleteMediaFromStorage,
                                                messagesToDelete:
                                                    widget.user.messages,
                                                user: widget.user);
                                          },
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'mute',
                              child: Text('Mute notifications'),
                            ),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Text('Clear Chat'),
                            ),
                          ],
                        ),
                      ],
                    ),
              body: Column(
                children: [
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: _userBox.listenable(),
                      builder: (context, Box<ChatUser> box, _) {
                        final user = box.get(widget.user.id);
                        if (user == null) {
                          return const Center(child: Text('User not found'));
                        }
                        // WidgetsBinding.instance
                        //     .addPostFrameCallback((_) => _scrollToBottom());
                        return ListView.builder(
                          controller: _scrollController,
                          cacheExtent: 500,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: user.messages.length,
                          itemBuilder: (context, index) {
                            final msg = user.messages[index];
                            return LongPressWrapper(
                                onLongPress: () {
                                  setState(() {
                                    _selectedMessages[index] = msg;
                                  });
                                },
                                onTap: () async {
                                  if (_isSelectionMode) {
                                    setState(() {
                                      if (_selectedMessages
                                          .containsKey(index)) {
                                        _selectedMessages.remove(index);
                                      } else {
                                        _selectedMessages[index] = msg;
                                      }
                                    });
                                  } else if (msg.type == 'image') {
                                    if (!msg.isMe && msg.status != 1.0) {
                                      return;
                                    }
                                    List<String> filePaths = user.messages
                                        .where((m) => m.type == 'image')
                                        .map((m) => m.filePath!)
                                        .toList();
                                    int cIndex =
                                        filePaths.indexOf(msg.filePath!);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => FullScreenImageViewer(
                                                filePaths: filePaths,
                                                initialIndex: cIndex,
                                              ),
                                          barrierDismissible: true),
                                    );
                                  } else if (msg.type == 'video') {
                                    if (!msg.isMe && msg.status != 1.0) {
                                      return;
                                    }
                                    List<String> videoPaths = user.messages
                                        .where((m) => m.type == 'video')
                                        .map((m) => m.filePath!)
                                        .toList();
                                    int vIndex =
                                        videoPaths.indexOf(msg.filePath!);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => VideoViewer(
                                                filePaths: videoPaths,
                                                initialIndex: vIndex,
                                                // tag: msg.filePath,
                                              ),
                                          barrierDismissible: true),
                                    );
                                  } else if (msg.type == 'file') {
                                    if (!msg.isMe && msg.status != 1.0) {
                                      return;
                                    }
                                    final result =
                                        await OpenFile.open(msg.filePath!);
                                    if (result.type != ResultType.done) {
                                      if (context.mounted) {
                                        showSnackbar(
                                            'Error: ${result.message}');
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                    color: _selectedMessages.containsKey(index)
                                        ? Colors.blue.withValues(alpha: .2)
                                        : Colors.transparent,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: msg.isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        Align(
                                          alignment: msg.isMe
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: msg.isMe
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : colorScheme.secondary,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: getWidgetForMsg(
                                                  msg, context)),
                                        ),
                                        buildStatusLabel(msg),
                                      ],
                                    )));
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.08),
                        ),
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .10),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(18)),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.attach_file),
                                    onPressed: isConnected
                                        ? () async {
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor:
                                                  Colors.transparent,
                                              isScrollControlled: true,
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                  top: Radius.circular(28),
                                                ),
                                              ),
                                              builder: (context) => SafeArea(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surface,
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                      top: Radius.circular(28),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                                alpha: 0.08),
                                                        blurRadius: 16,
                                                        offset:
                                                            const Offset(0, -4),
                                                      ),
                                                    ],
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 24,
                                                      horizontal: 8),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 40,
                                                        height: 4,
                                                        margin: const EdgeInsets
                                                            .only(bottom: 16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[300],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(2),
                                                        ),
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceEvenly,
                                                        children: [
                                                          AttachmentAction(
                                                            icon: Icons.image,
                                                            color:
                                                                Colors.purple,
                                                            label: 'Image',
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                              pickImage(
                                                                _userBox,
                                                                widget.user.id,
                                                                _scrollToBottom,
                                                                showSnackbar,
                                                              );
                                                            },
                                                          ),
                                                          AttachmentAction(
                                                            icon: Icons
                                                                .video_collection,
                                                            color: Colors
                                                                .redAccent,
                                                            label: 'Video',
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                              pickVideo(
                                                                _userBox,
                                                                widget.user.id,
                                                                _scrollToBottom,
                                                                showSnackbar,
                                                              );
                                                            },
                                                          ),
                                                          AttachmentAction(
                                                            icon: Icons
                                                                .audio_file,
                                                            color: Colors.teal,
                                                            label: 'Audio',
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                              pickFile(
                                                                'audio',
                                                                _userBox,
                                                                widget.user.id,
                                                                _scrollToBottom,
                                                                showSnackbar,
                                                              );
                                                            },
                                                          ),
                                                          AttachmentAction(
                                                            icon: Icons
                                                                .insert_drive_file,
                                                            color:
                                                                Colors.blueGrey,
                                                            label: 'File',
                                                            onTap: () {
                                                              Navigator.pop(
                                                                  context);
                                                              pickFile(
                                                                'file',
                                                                _userBox,
                                                                widget.user.id,
                                                                _scrollToBottom,
                                                                showSnackbar,
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      minLines: 1,
                                      maxLines: 6,
                                      decoration: const InputDecoration(
                                          hintText: 'Type a message...',
                                          fillColor: Colors.transparent),
                                      onSubmitted: (_) => _sendMessage(),
                                      onChanged: (value) {
                                        setState(
                                            () {}); // Rebuild to show/hide audio recorder
                                      },
                                      enabled: isConnected,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => isConnected
                                        ? openCamera(_userBox, widget.user.id,
                                            _scrollToBottom, showSnackbar)
                                        : null,
                                    icon: const Icon(Icons.camera_alt),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _controller.text.trim().isEmpty
                              ? AudioRecorderWidget(
                                  onRecordingComplete: onAudioRecordingComplete,
                                  isConnected: isConnected,
                                )
                              : ElevatedButton(
                                  onPressed: isConnected ? _sendMessage : null,
                                  style: ElevatedButton.styleFrom(
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ));
      },
    );
  }
}

class LongPressWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const LongPressWrapper(
      {super.key, required this.child, this.onLongPress, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: child,
    );
  }
}
