import 'dart:async';
import 'dart:io';
import 'package:airchat/providers/connection_state_provider.dart';
import 'package:airchat/providers/call_state_provider.dart';
import 'package:airchat/services/overlay_service.dart';
import 'package:airchat/ui/calling_screen.dart';
import 'package:airchat/utility/audio_recorder.dart';
import 'package:airchat/utility/image_viewer.dart';
import 'package:airchat/utility/media_selection.dart';
import 'package:airchat/utility/video_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../utility/snackbar_util.dart';
import '../widgets/chat_screen_helpers.dart';

class DesktopChatSection extends StatefulWidget {
  final ChatUser user;
  final VoidCallback? onBack;
  final VoidCallback? onInfoToggle;

  const DesktopChatSection(
      {super.key, required this.user, this.onBack, this.onInfoToggle});

  @override
  State<DesktopChatSection> createState() => _DesktopChatSectionState();
}

class _DesktopChatSectionState extends State<DesktopChatSection> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _fileTransferProgressSubscription;
  late Box<ChatUser> _userBox;
  late final FocusNode _messageFocusNode;
  int? _hoveredMessageIndex;
  int _loadedCount = 10;
  bool _isLoadingMore = false;
  late List<ChatMessage> _allMessages;

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
    _allMessages = user?.messages ?? [];

    _messageFocusNode = FocusNode(
      onKeyEvent: (FocusNode node, KeyEvent evt) {
        if (!HardwareKeyboard.instance.isShiftPressed &&
            evt.logicalKey.keyLabel == 'Enter') {
          if (evt is KeyDownEvent) {
            _sendMessage(widget.user);
          }
          return KeyEventResult.handled;
        } else {
          return KeyEventResult.ignored;
        }
      },
    );
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
          if (kDebugMode) {
            print('Error finding message for payload $payloadId: $e');
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() async {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _loadedCount += 10;
        _isLoadingMore = false;
      });
    }
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
    _messageController.dispose();
    _fileTransferProgressSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = widget.user;

    final messages = _allMessages.length > _loadedCount
        ? _allMessages.sublist(_allMessages.length - _loadedCount)
        : _allMessages;
    return Consumer2<ConnectionStateProvider, CallStateProvider>(
        builder: (context, connProvider, callProvider, _) {
      // Determine status
      String statusText;
      Color statusColor;
      final isConnected =
          connProvider.connectedPeers.any((p) => p.userId == user.id);
      final isAvailable = connProvider.discovered.containsKey(user.id);
      if (isConnected) {
        statusText = 'Connected';
        statusColor = Colors.green;
      } else if (isAvailable) {
        statusText = 'Available';
        statusColor = Colors.blueAccent;
      } else {
        statusText = 'Not Available';
        statusColor = Colors.blueGrey;
      }

      return Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: .12),
                ),
              ),
            ),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: widget.onBack,
                    // tooltip: 'Back',
                    color: colorScheme.onSurface,
                    hoverColor: Colors.transparent,
                  ),
                  SizedBox(width: 8,),
                CircleAvatar(
                  backgroundColor: statusColor,
                  radius: 22,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor),
                    )
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: (isConnected || isAvailable)
                      ? () async {
                          try {
                            final id = DateTime.now().toIso8601String();
                            callProvider.startOutgoingCall(widget.user.id, id);
                            await ConnectionService.sendCallInvite(
                                widget.user.id, id);
                            if (Platform.isAndroid || Platform.isIOS) {
                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CallScreen(user: user),
                                  ),
                                );
                              }
                            } else {
                              DraggableOverlayService().showOverlay(user);
                            }
                          } catch (e) {
                            showSnackbar(e.toString());
                          }
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('User not available for call')),
                          );
                        },
                  tooltip: 'Voice Call',
                ),
                // IconButton(
                //   icon: const Icon(Icons.videocam, ),
                //   onPressed: null, // Video call not implemented yet
                //   tooltip: 'Video Call',
                // ),
                if (widget.onInfoToggle != null)
                  IconButton(
                    icon: const Icon(
                      Icons.info_outline,
                    ),
                    onPressed: widget.onInfoToggle,
                    tooltip: 'User Info',
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'More options',
                  onSelected: (value) {
                    if (value == 'mute') {
                      showSnackbar('Mute notifications not implemented');
                    } else if (value == 'clear') {
                      bool deleteMediaFromStorage = false;

                      showDialog(
                        context: context,
                        builder: (context) {
                          return StatefulBuilder(
                            builder: (context, setState) => AlertDialog(
                              title: Text(
                                'Delete${user.messages.length > 1 ? ' ${user.messages.length}' : ''} message${user.messages.length > 1 ? 's' : ''}?',
                                style: TextStyle(fontSize: 18),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CheckboxListTile(
                                    value: deleteMediaFromStorage,
                                    onChanged: (val) {
                                      setState(() {
                                        deleteMediaFromStorage = val ?? false;
                                      });
                                    },
                                    title:
                                        const Text('Delete media from device'),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                        side: BorderSide(color: colorScheme.onTertiary)
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child:  Text('Cancel', style: TextStyle(color: colorScheme.onTertiary),),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                    await deleteMessages(
                                        deleteMedia: deleteMediaFromStorage,
                                        messagesToDelete: user.messages, user:user);
                                  },
                                  child: const Text('Delete', style: TextStyle(color:Colors.red),),
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
          ),
          // Messages area
          if (_isLoadingMore) const Center(child: CircularProgressIndicator()),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              cacheExtent: 500,
              padding: const EdgeInsets.symmetric( vertical: 4),
              itemCount: messages.length,
              itemBuilder: (context, idx) {
                final msg = messages[idx];

                Widget bubble = GestureDetector(
                    onTap: () async {
                      if (msg.type == 'image') {
                        if (!msg.isMe && msg.status != 1.0) {
                          return;
                        }
                        List<String> filePaths = user.messages
                            .where((m) => m.type == 'image')
                            .map((m) => m.filePath!)
                            .toList();
                        int cIndex = filePaths.indexOf(msg.filePath!);
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
                        int vIndex = videoPaths.indexOf(msg.filePath!);
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
                        final result = await OpenFile.open(msg.filePath!);
                        if (result.type != ResultType.done) {
                          if (context.mounted) {
                            showSnackbar('Error: ${result.message}');
                          }
                        }
                      }
                    },
                    child: Container(
                        // color: _selectedMessages.containsKey(index)
                        //     ? Colors.blue.withValues(alpha: .2)
                        //     : null,
                        padding: EdgeInsets.symmetric(horizontal: 16,),
                        margin: const EdgeInsets.symmetric(vertical: 4),
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
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? Theme.of(context).primaryColor
                                        : colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: getWidgetForMsg(msg, context)),
                            ),
                            buildStatusLabel(msg),
                          ],
                        )));
                return MessageBubbleWithMenu(
                  msgType: msg.type,
                  isMe: msg.isMe,
                  idx: idx,
                  hoveredIdx: _hoveredMessageIndex,
                  onHover: (i) => setState(() => _hoveredMessageIndex = i),
                  onExit: () => setState(() => _hoveredMessageIndex = null),
                  onMenuSelected: (action) async {
                    if (action == 'copy') {
                      if (msg.type == 'text') {
                        await Clipboard.setData(ClipboardData(text: msg.text));
                        showSnackbar('Message copied');
                      }
                      // Optionally handle copy for other types
                    } else if (action == 'forward') {
                      showSnackbar('Forward not implemented');
                    } else if (action == 'delete') {
                      final user = _userBox.get(widget.user.id);
                      if (user != null) {
                        user.messages.removeAt(idx);
                        user.save();
                      }
                    }
                  },
                  child: bubble,
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.08),
                ),
              ),
              boxShadow: [
                if (Theme.of(context).brightness == Brightness.light)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file,
                      color: isConnected
                          ? null
                          : colorScheme.onSurface.withValues(alpha: 0.4)),
                  onPressed: () {
                    if (isConnected) {
                      // Show the menu at the click position by using RenderBox and localToGlobal
                      final RenderBox button =
                          context.findRenderObject() as RenderBox;
                      final Offset buttonPosition =
                          button.localToGlobal(Offset.zero);
                      final Size buttonSize = button.size;
                      showMenu(
                        context: context,
                        color: colorScheme.primary,
                        position: RelativeRect.fromLTRB(
                          buttonPosition.dx,
                          buttonPosition.dy + buttonSize.height,
                          buttonPosition.dx + buttonSize.width,
                          buttonPosition.dy,
                        ),
                        items: [
                          PopupMenuItem(
                            child: ListTile(
                              leading: Icon(
                                Icons.image,
                                color: Colors.white,
                              ),
                              title: Text(
                                'Send Image',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                pickImage(_userBox, user.id, _scrollToBottom,
                                    showSnackbar);
                              },
                            ),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              leading: Icon(Icons.video_collection,
                                  color: Colors.white),
                              title: Text(
                                'Send Video',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                pickVideo(_userBox, user.id, _scrollToBottom,
                                    showSnackbar);
                              },
                            ),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              leading:
                                  Icon(Icons.audio_file, color: Colors.white),
                              title: Text(
                                'Send Audio',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                pickFile('audio', _userBox, user.id,
                                    _scrollToBottom, showSnackbar);
                              },
                            ),
                          ),
                          PopupMenuItem(
                            child: ListTile(
                              leading: Icon(Icons.insert_drive_file,
                                  color: Colors.white),
                              title: Text(
                                'Send File',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                pickFile('file', _userBox, user.id,
                                    _scrollToBottom, showSnackbar);
                              },
                            ),
                          ),
                        ],
                      );
                    }
                  },
                  tooltip: 'Attach File',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: isConnected,
                    autofocus: true,
                    focusNode: _messageFocusNode,
                    minLines: 1,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    // keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText:
                          isConnected ? 'Type a message...' : 'Not connected',
                      hintStyle: TextStyle(
                        color: isConnected
                            ? colorScheme.onSurface.withValues(alpha: 0.6)
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: isConnected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    // Remove onSubmitted to avoid double send
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => isConnected
                      ? openCamera(_userBox, widget.user.id, _scrollToBottom,
                          showSnackbar)
                      : null,
                  icon: Icon(Icons.camera_alt,
                      color: isConnected
                          ? null
                          : colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                const SizedBox(width: 4),
                _messageController.text.trim().isEmpty
                    ? AudioRecorderWidget(
                        onRecordingComplete: onAudioRecordingComplete,
                        isConnected: isConnected,
                      )
                    : FloatingActionButton(
                        heroTag: 'desktop',
                        mini: true,
                        backgroundColor: isConnected
                            ? colorScheme.primary
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                        onPressed: () =>
                            isConnected ? _sendMessage(user) : null,
                        elevation: 0,
                        child: Icon(Icons.send,
                            color: isConnected
                                ? Colors.white
                                : colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
              ],
            ),
          ),
        ],
      );
    });
  }

  void _sendMessage(ChatUser toUser) async {
    try {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      final user = _userBox.get(toUser.id);
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

      _messageController.clear();
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

  void showSnackbar(String message) {
    SnackbarUtil.show(context, message: message);
  }
}

class MessageBubbleWithMenu extends StatelessWidget {
  final Widget child;
  final String msgType;
  final bool isMe;
  final int idx;
  final int? hoveredIdx;
  final void Function(int) onHover;
  final void Function() onExit;
  final void Function(String action) onMenuSelected;

  const MessageBubbleWithMenu({
    required this.child,
    required this.msgType,
    required this.isMe,
    required this.idx,
    required this.hoveredIdx,
    required this.onHover,
    required this.onExit,
    required this.onMenuSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    bool isOpen = false;
    return MouseRegion(
      onHover: (_) => onHover(idx),
      onExit: (_) => !isOpen ? onExit() : null,
      // hitTestBehavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (hoveredIdx == idx)
            Positioned(
              top: 5,
              right: isMe ? 20 : null,
              left: isMe ? null : 20,
              child: PopupMenuButton<String>(
                // icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20,),
                elevation: 20,
                onSelected: onMenuSelected,
                onOpened: () => isOpen = true,
                onCanceled: () => isOpen = false,
                itemBuilder: (context) => [
                  if (msgType == 'text')
                    const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  const PopupMenuItem(value: 'forward', child: Text('Forward')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      )),
                ],
                tooltip: 'Actions',
                color: Theme.of(context).cardColor,
                child: Container(
                  decoration: BoxDecoration(
                         borderRadius: const BorderRadius.only(
                           topLeft: Radius.circular(16),
                           topRight: Radius.circular(16),
                          //  bottomLeft: Radius.circular(0),
                          //  bottomRight: Radius.circular(16),
                         ),
                    color: isMe?Theme.of(context).colorScheme.primary:
                         Theme.of(context).colorScheme.secondary,
                  ),
                  child: 
                Icon(Icons.keyboard_arrow_down_rounded, size: 24,),
              )),
            ),
        ],
      ),
    );
  }
}
