import 'dart:async';
import 'dart:io';
import 'package:airchat/providers/connection_state_provider.dart';
import 'package:airchat/providers/call_state_provider.dart';
import 'package:airchat/services/overlay_service.dart';
import 'package:airchat/ui/calling_screen.dart';
import 'package:airchat/utility/audio_recorder.dart';
import 'package:airchat/utility/media_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../utility/audio_player.dart';
import '../utility/video_viewer.dart';
import '../utility/image_viewer.dart';
import '../utility/snackbar_util.dart';
import 'package:open_file/open_file.dart';
import '../widgets/chat_screen_helpers.dart';

class DesktopChatSection extends StatefulWidget {
  final ChatUser user;
  final List<ChatMessage> messages;
  final VoidCallback? onBack;
  final VoidCallback? onInfoToggle;

  const DesktopChatSection(
      {super.key,
      required this.user,
      required this.messages,
      this.onBack,
      this.onInfoToggle});

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ConnectionService.fileTransferProgressStream.listen((event) {
      if (event == null) return;
      final payloadId = event['id'];
      final progress = event['progress'];
      if (progress != null && progress >= 0 && progress <= 1) {
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
    final messages = widget.messages;
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                    tooltip: 'Back',
                    color: colorScheme.onSurface,
                  ),
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
                        final user = _userBox.get(widget.user.id);
                        if (user != null) {
                          user.messages.clear();
                          user.save();                          
                        }
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
          Expanded(
            child: Container(
              color: colorScheme.surface,
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                itemCount: messages.length,
                itemBuilder: (context, idx) {
                  final msg = messages[idx];
                  Widget? bubble;
                  // IMAGE
                  if (msg.type == 'image' && msg.filePath != null) {
                    bubble = Column(
                      crossAxisAlignment: msg.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () async {
                              if (!msg.isMe && msg.status != 1.0) return;
                              List<String> filePaths = messages
                                  .where((m) => m.type == 'image')
                                  .map((m) => m.filePath!)
                                  .toList();
                              int cIndex = filePaths.indexOf(msg.filePath!);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    filePaths: filePaths,
                                    initialIndex: cIndex,
                                    // tag: msg.filePath,
                                  ),
                                  barrierDismissible: true,
                                ),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? colorScheme.primary
                                        : colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: (!msg.isMe && msg.status != 1.0)
                                        ? const SizedBox(
                                            height: 180, width: 180)
                                        : Image.file(
                                            File(msg.filePath!),
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: SizedBox(
                                                width: 180,
                                                height: 180,
                                                child: Center(
                                                  child: Text(
                                                    'Image not found',
                                                    style: TextStyle(
                                                      color: msg.isMe
                                                          ? Colors.white
                                                          : colorScheme
                                                              .onSurface,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (msg.transferProgress != null &&
                                    msg.transferProgress! < 1.0 &&
                                    msg.status == 3)
                                  Positioned.fill(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Center(
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: CircularProgressIndicator(
                                              value: msg.transferProgress,
                                              backgroundColor: Colors.white24,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      colorScheme.primary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  }
                  // VIDEO
                  else if (msg.type == 'video' && msg.filePath != null) {
                    bubble = Column(
                      crossAxisAlignment: msg.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () async {
                              if (!msg.isMe && msg.status != 1.0) return;
                              List<String> videoPaths = messages
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
                                  barrierDismissible: true,
                                ),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? colorScheme.primary
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: (!msg.isMe && msg.status != 1.0)
                                        ? const SizedBox(
                                            height: 180, width: 180)
                                        : Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              VideoThumbnailWidget(
                                                  filePath: msg.filePath!),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.white,
                                                    size: 48),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                if (msg.transferProgress != null &&
                                    msg.transferProgress! < 1.0 &&
                                    msg.status == 3)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: CircularProgressIndicator(
                                            value: msg.transferProgress,
                                            backgroundColor: Colors.white24,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.blueAccent),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  }
                  // AUDIO
                  else if (msg.type == 'audio') {
                    bubble = Column(
                      crossAxisAlignment: msg.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: msg.filePath != null && msg.status == 1
                              ? SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.3,
                                  // constraints: BoxConstraints(
                                  //   maxWidth:
                                  //       MediaQuery.of(context).size.width * 0.5,
                                  // ),
                                  child: AudioPlayerWidget(
                                    filePath: msg.filePath!,
                                    isMe: msg.isMe,
                                  ))
                              : Container(
                                  height: 40,
                                  width:
                                      MediaQuery.of(context).size.width * 0.3,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? colorScheme.primary
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.audiotrack,
                                          color: msg.isMe
                                              ? Colors.white
                                              : colorScheme.onSurface
                                                  .withValues(alpha: 0.6)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          msg.fileName ?? 'Audio',
                                          style: TextStyle(
                                            color: msg.isMe
                                                ? Colors.white
                                                : colorScheme.onSurface,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  }
                  // FILE
                  else if (msg.type == 'file') {
                    bubble = Column(
                      crossAxisAlignment: msg.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: msg.filePath != null
                                ? () async {
                                    if (!msg.isMe && msg.status != 1.0) {
                                      return;
                                    }
                                    final result =
                                        await OpenFile.open(msg.filePath!);
                                    if (result.type != ResultType.done) {
                                      if (context.mounted) {
                                        SnackbarUtil.show(context,
                                            message:
                                                'Error: \\${result.message}');
                                      }
                                    }
                                  }
                                : null,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: msg.isMe
                                        ? colorScheme.primary
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    child: ListTile(
                                      leading: getFileIcon(msg.fileName),
                                      title: Text(
                                        msg.fileName ?? 'File',
                                        style: TextStyle(
                                          color: msg.isMe
                                              ? Colors.white
                                              : colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      subtitle: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            getFileType(msg.fileName),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: msg.isMe
                                                  ? Colors.white70
                                                  : colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                            ),
                                          ),
                                          msg.filePath != null
                                              ? Text(
                                                  '  ${formatFileSize(msg.filePath)}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: msg.isMe
                                                        ? Colors.white70
                                                        : colorScheme.onSurface
                                                            .withValues(
                                                                alpha: 0.6),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (msg.transferProgress != null &&
                                    msg.transferProgress! < 1.0 &&
                                    msg.status == 3)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.black26,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: CircularProgressIndicator(
                                            value: msg.transferProgress,
                                            backgroundColor: Colors.white30,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.blueAccent),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  }
                  // TEXT
                  else if (msg.type == 'text') {
                    bubble = Column(
                      crossAxisAlignment: msg.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: msg.isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints:  BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.3),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: msg.isMe
                                  ? colorScheme.primary
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
                            child: Text(
                              msg.text,
                              style: TextStyle(
                                color: msg.isMe
                                    ? Colors.white
                                    : colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  } else if (msg.type == 'call') {
                    // CALL
                    bubble = Column(
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
                              maxWidth: MediaQuery.of(context).size.width * 0.3,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: msg.isMe
                                  ? theme.primaryColor.withValues(alpha: .1)
                                  : colorScheme.secondary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: msg.isMe
                                    ? theme.primaryColor
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  msg.isMe
                                      ? Icons.call_made
                                      : Icons.call_received,
                                  color: msg.isMe
                                      ? Theme.of(context).primaryColor
                                      : Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Builder(
                                    builder: (_) {
                                      // Outgoing
                                      if (msg.isMe) {
                                        if (msg.text == 'Outgoing') {
                                          if (msg.duration == null ||
                                              msg.duration!.isEmpty) {
                                            // Not answered
                                            return Text(
                                              'Not answered',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          } else {
                                            return Text(
                                              'Outgoing • ${msg.duration}',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        // Incoming
                                        // if (msg.text == 'Outgoing') {
                                        // This is an incoming missed call
                                        if (msg.duration == null ||
                                            msg.duration!.isEmpty) {
                                          return Text(
                                            'Missed call',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        } else {
                                          return Text(
                                            'Incoming • ${msg.duration}',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        }
                                        // }
                                      }
                                      // Fallback
                                      return Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        buildStatusLabel(msg),
                      ],
                    );
                  }
                  if (bubble == null) {
                    return const SizedBox.shrink();
                  }
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
                          await Clipboard.setData(
                              ClipboardData(text: msg.text));
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
          ),
          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
      onExit: (_) => !isOpen? onExit(): null,  
      // hitTestBehavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (hoveredIdx == idx)
            Positioned(
              top: 0,
              right: isMe?0:null,
              // left: isMe ? null : 0,
              child: PopupMenuButton<String>(
                // icon: const Icon(Icons.arrow_drop_down_sharp, size: 20),
                elevation: 20,
                onSelected: onMenuSelected,
                onOpened: ()=> isOpen = true,
                onCanceled: ()=> isOpen = false,
                itemBuilder: (context) => [
                  if(msgType == 'text')
                  const PopupMenuItem(value: 'copy', child: Text('Copy')),
                  const PopupMenuItem(value: 'forward', child: Text('Forward')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red),)),
                ],
                tooltip: 'More options',                                
                color: Theme.of(context).cardColor,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    cardColor: Theme.of(context).cardColor.withValues(alpha: .85), // make bg a little blurrier
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.arrow_drop_down, size: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
