import 'dart:async';
import 'dart:io';
import 'package:airchat/providers/connection_state_provider.dart';
import 'package:airchat/providers/call_state_provider.dart';
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
import '../services/calling_service.dart';

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
  final LanCallService _callService = LanCallService();

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
    final colorScheme = Theme.of(context).colorScheme;
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

      return Stack(
        children: [
          Column(
            children: [
              // Chat header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withValues(alpha: .12),
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
                      ),
                    CircleAvatar(
                      backgroundColor: statusColor,
                      radius: 22,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        // You can add online/offline status here if needed
                        Text(
                          statusText,
                          style: TextStyle(color: statusColor),
                        )
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.indigo),
                      onPressed: (isConnected || isAvailable)
                          ? () async {
                              final id = DateTime.now().toIso8601String();
                              callProvider.startOutgoingCall(
                                  widget.user.id, id);
                              await ConnectionService.sendCallInvite(
                                  widget.user.id, id);

                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CallScreen(user: user),
                                  ),
                                );
                              }
                            }
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('User not available for call')),
                              );
                            },
                      tooltip: 'Voice Call',
                    ),
                    IconButton(
                      icon: const Icon(Icons.videocam, color: Colors.indigo),
                      onPressed: null, // Video call not implemented yet
                      tooltip: 'Video Call',
                    ),
                    if (widget.onInfoToggle != null)
                      IconButton(
                        icon: const Icon(Icons.info_outline,
                            color: Colors.indigo),
                        onPressed: widget.onInfoToggle,
                        tooltip: 'User Info',
                      ),
                  ],
                ),
              ),
              // Messages area
              Expanded(
                child: Container(
                  color: Colors.grey[50],
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 24),
                    itemCount: messages.length,
                    itemBuilder: (context, idx) {
                      final msg = messages[idx];
                      // IMAGE
                      if (msg.type == 'image' && msg.filePath != null) {
                        return Column(
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
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: msg.isMe
                                            ? colorScheme.primary
                                            : Colors.grey[200],
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
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
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
                                                              : Colors.black,
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
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Center(
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child:
                                                    CircularProgressIndicator(
                                                  value: msg.transferProgress,
                                                  backgroundColor:
                                                      Colors.white24,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                              Color>(
                                                          Colors.blueAccent),
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
                        return Column(
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
                                  int vIndex =
                                      videoPaths.indexOf(msg.filePath!);
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
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: msg.isMe
                                            ? colorScheme.primary
                                            : Colors.grey[200],
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
                                                          BorderRadius.circular(
                                                              12),
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
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CircularProgressIndicator(
                                                value: msg.transferProgress,
                                                backgroundColor: Colors.white24,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
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
                        return Column(
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
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
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
                                      width: MediaQuery.of(context).size.width *
                                          0.3,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: msg.isMe
                                            ? colorScheme.primary
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.audiotrack,
                                              color: msg.isMe
                                                  ? Colors.white
                                                  : Colors.black54),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              msg.fileName ?? 'Audio',
                                              style: TextStyle(
                                                color: msg.isMe
                                                    ? Colors.white
                                                    : Colors.black87,
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
                        return Column(
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
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                        color: msg.isMe
                                            ? colorScheme.primary
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: SizedBox(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.3,
                                        child: ListTile(
                                          leading: getFileIcon(msg.fileName),
                                          title: Text(
                                            msg.fileName ?? 'File',
                                            style: TextStyle(
                                              color: msg.isMe
                                                  ? Colors.white
                                                  : Colors.black87,
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
                                                      : Colors.black54,
                                                ),
                                              ),
                                              msg.filePath != null
                                                  ? Text(
                                                      '  ${formatFileSize(msg.filePath)}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: msg.isMe
                                                            ? Colors.white70
                                                            : Colors.black54,
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
                                            borderRadius:
                                                BorderRadius.circular(16),
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
                                                    AlwaysStoppedAnimation<
                                                            Color>(
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
                        return Column(
                          crossAxisAlignment: msg.isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: msg.isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 400),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: msg.isMe
                                      ? colorScheme.primary
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
                                    color: msg.isMe
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            buildStatusLabel(msg),
                          ],
                        );
                      } else if (msg.type == 'call') {
                        // WhatsApp-like call message UI
                        return Column(
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
                                      MediaQuery.of(context).size.width * 0.6,
                                ),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: msg.isMe
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withValues(alpha: .1)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: msg.isMe
                                        ? Theme.of(context).primaryColor
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
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              // Message input
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.withValues(alpha: .12),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file,
                          color:
                              isConnected ? colorScheme.primary : Colors.grey),
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
                                    pickImage(_userBox, user.id,
                                        _scrollToBottom, showSnackbar);
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
                                    pickVideo(_userBox, user.id,
                                        _scrollToBottom, showSnackbar);
                                  },
                                ),
                              ),
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(Icons.audio_file,
                                      color: Colors.white),
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
                          hintText: isConnected
                              ? 'Type a message...'
                              : 'Not connected',
                          hintStyle: TextStyle(
                            color: isConnected
                                ? Colors.grey[600]
                                : Colors.grey[400],
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor:
                              isConnected ? Colors.grey[50] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(
                              color: colorScheme.primary.withValues(alpha: .3),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 20),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isConnected ? Colors.black87 : Colors.grey[600],
                        ),
                        // Remove onSubmitted to avoid double send
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () => isConnected
                          ? openCamera(_userBox, widget.user.id,
                              _scrollToBottom, showSnackbar)
                          : null,
                      icon: Icon(Icons.camera_alt,
                          color:
                              isConnected ? colorScheme.primary : Colors.grey),
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
                            backgroundColor:
                                isConnected ? colorScheme.primary : Colors.grey,
                            onPressed: () =>
                                isConnected ? _sendMessage(user) : null,
                            elevation: 0,
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                  ],
                ),
              ),
            ],
          ),
          Consumer2<ConnectionStateProvider, CallStateProvider>(
            builder: (context, connProvider, callProvider, _) {
              if (callProvider.callState == CallState.inCall &&
                  callProvider.currentCallUserId == widget.user.id) {
                return Positioned(
                  right: 32,
                  bottom: 32,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    child: Container(
                      width: 320,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('In Call with ${widget.user.name}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(height: 8),
                          Text(callProvider.formattedCallDuration,
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.mic_off),
                                tooltip: 'Mute',
                                onPressed: () {
                                  // TODO: Implement mute
                                },
                              ),
                              SizedBox(width: 24),
                              IconButton(
                                icon: Icon(Icons.call_end, color: Colors.red),
                                tooltip: 'Hang Up',
                                onPressed: () async {
                                  await ConnectionService.updateCallDuration(
                                      callProvider.currentCallUserId!,
                                      callProvider.callId!,
                                      callProvider.callState == CallState.inCall
                                          ? callProvider.formattedCallDuration
                                          : null,
                                      callProvider.callDirection!);

                                  callProvider.endCall();
                                  await ConnectionService.sendCallEnd(
                                      widget.user.id, callProvider.callId!);
                                  await _callService.endCall();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
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
