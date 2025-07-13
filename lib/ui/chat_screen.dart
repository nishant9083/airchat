import 'dart:async';
import 'dart:io';
import 'package:airchat/ui/calling_screen.dart';
import 'package:airchat/utility/audio_player.dart';
import 'package:airchat/utility/image_viewer.dart';
import 'package:airchat/utility/audio_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
        // Main UI
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: ValueListenableBuilder(
                  valueListenable: _userBox.listenable(),
                  builder: (context, Box<ChatUser> box, _) {
                    final user = box.get(widget.user.id);
                    return Text(user?.name ?? 'Unknown');
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
                              
                                final id = DateTime.now().toIso8601String();                        
                                callProvider.startOutgoingCall(widget.user.id, id);        
                                await ConnectionService.sendCallInvite(
                                    widget.user.id, id);                                                                       
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CallScreen(user: widget.user),
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
                      );
                    },
                  ),
                ],
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
                                color: statusColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: _userBox.listenable(),
                      builder: (context, Box<ChatUser> box, _) {
                        final user = box.get(widget.user.id);
                        if (user == null) {
                          return const Center(child: Text('User not found'));
                        }
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _scrollToBottom());
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: user.messages.length,
                          itemBuilder: (context, index) {
                            final msg = user.messages[index];
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
                                              builder: (_) =>
                                                  FullScreenImageViewer(
                                                    filePaths: filePaths,
                                                    initialIndex: cIndex,
                                                  ),
                                              barrierDismissible: true),
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
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: (!msg.isMe &&
                                                      msg.status != 1.0)
                                                  ? SizedBox(
                                                      height: 180,
                                                      width: 180,
                                                    )
                                                  : Image.file(
                                                      File(msg.filePath!),
                                                      width: 180,
                                                      height: 180,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: SizedBox(
                                                          width: 180,
                                                          height: 180,
                                                          child: Center(
                                                            child: Text(
                                                              'Image not found',
                                                              style: TextStyle(
                                                                color: msg.isMe
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black,
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
                                                margin:
                                                    const EdgeInsets.symmetric(
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
                                                        value: msg
                                                            .transferProgress,
                                                        backgroundColor:
                                                            Colors.white24,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors
                                                                    .blueAccent),
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
                            } else if (msg.type == 'video' &&
                                msg.filePath != null) {
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
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: (!msg.isMe &&
                                                      msg.status != 1.0)
                                                  ? SizedBox(
                                                      height: 180,
                                                      width: 180,
                                                    )
                                                  : Stack(
                                                      alignment:
                                                          Alignment.center,
                                                      children: [
                                                        // Video thumbnail
                                                        VideoThumbnailWidget(
                                                            filePath:
                                                                msg.filePath!),
                                                        Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            color:
                                                                Colors.black45,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: const Icon(
                                                              Icons.play_arrow,
                                                              color:
                                                                  Colors.white,
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
                                                    child:
                                                        CircularProgressIndicator(
                                                      value:
                                                          msg.transferProgress,
                                                      backgroundColor:
                                                          Colors.white24,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors
                                                                  .blueAccent),
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
                            } else if (msg.type == 'audio') {
                              return Column(
                                crossAxisAlignment: msg.isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Align(
                                      alignment: msg.isMe
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Stack(
                                        children: [
                                          SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(0.0),
                                                child: msg.filePath != null &&
                                                        msg.status == 1
                                                    ? AudioPlayerWidget(
                                                        filePath: msg.filePath!,
                                                        isMe: msg.isMe)
                                                    : Container(
                                                        height: 40,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 4,
                                                                horizontal: 4),
                                                        decoration: BoxDecoration(
                                                            color: msg.isMe
                                                                ? Theme.of(
                                                                        context)
                                                                    .primaryColor
                                                                : Colors
                                                                    .grey[200],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                                Icons
                                                                    .audiotrack,
                                                                color: msg.isMe
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black54),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                msg.fileName ??
                                                                    'Audio',
                                                                style:
                                                                    TextStyle(
                                                                  color: msg
                                                                          .isMe
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                maxLines: 1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                          ),
                                          if (msg.transferProgress != null &&
                                              msg.transferProgress! < 1.0 &&
                                              msg.status == 3)
                                            Positioned.fill(
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 0.0),
                                                  child: Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                        value: msg
                                                            .transferProgress,
                                                        backgroundColor:
                                                            Colors.white24,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                Colors
                                                                    .blueAccent),
                                                      ),
                                                    ),
                                                  )),
                                            )
                                        ],
                                      )),
                                  buildStatusLabel(msg),
                                ],
                              );
                            } else if (msg.type == 'file') {
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
                                              if (!msg.isMe &&
                                                  msg.status != 1.0) {
                                                return;
                                              }
                                              final result =
                                                  await OpenFile.open(
                                                      msg.filePath!);
                                              if (result.type !=
                                                  ResultType.done) {
                                                if (context.mounted) {
                                                  showSnackbar(
                                                      'Error: ${result.message}');
                                                }
                                              }
                                            }
                                          : null,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            // padding: const EdgeInsets.all(2),
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            decoration: BoxDecoration(
                                              color: msg.isMe
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: SizedBox(
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.7,
                                              child: ListTile(
                                                  leading:
                                                      getFileIcon(msg.fileName),
                                                  title: Text(
                                                    msg.fileName ?? 'File',
                                                    style: TextStyle(
                                                        color: msg.isMe
                                                            ? Colors.white
                                                            : Colors.black87),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  subtitle: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          getFileType(
                                                              msg.fileName),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: msg.isMe
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black54,
                                                          ),
                                                        ),
                                                        msg.filePath != null
                                                            ? Text(
                                                                ' \u2022 ${formatFileSize(msg.filePath)}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  color: msg
                                                                          .isMe
                                                                      ? Colors
                                                                          .white70
                                                                      : Colors
                                                                          .black54,
                                                                ),
                                                              )
                                                            : const SizedBox
                                                                .shrink(),
                                                      ])),
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
                                                    child:
                                                        CircularProgressIndicator(
                                                      value:
                                                          msg.transferProgress,
                                                      backgroundColor:
                                                          Colors.white30,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors
                                                                  .blueAccent),
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
                            } else if (msg.type == 'text') {
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
                                            MediaQuery.of(context).size.width *
                                                0.6,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
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
                            }
                            else if (msg.type == 'call'){
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
                                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: msg.isMe
                                          ? Theme.of(context).primaryColor.withValues(alpha: .1)
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
                                                  if (msg.duration == null || msg.duration!.isEmpty) {
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
                                                        color: Theme.of(context).primaryColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } else {
                                                // Incoming
                                                // if (msg.text == 'Outgoing') {
                                                  // This is an incoming missed call
                                                  if (msg.duration == null || msg.duration!.isEmpty) {
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
                            return SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                                            builder: (context) => SafeArea(
                                              child: Wrap(
                                                children: [
                                                  ListTile(
                                                    leading:
                                                        const Icon(Icons.image),
                                                    title: const Text(
                                                        'Send Image'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      pickImage(
                                                          _userBox,
                                                          widget.user.id,
                                                          _scrollToBottom,
                                                          showSnackbar);
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(
                                                        Icons.video_collection),
                                                    title: const Text(
                                                        'Send Video'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      pickVideo(
                                                          _userBox,
                                                          widget.user.id,
                                                          _scrollToBottom,
                                                          showSnackbar);
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(
                                                        Icons.audio_file),
                                                    title: const Text(
                                                        'Send Audio'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      pickFile(
                                                          'audio',
                                                          _userBox,
                                                          widget.user.id,
                                                          _scrollToBottom,
                                                          showSnackbar);
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons
                                                        .insert_drive_file),
                                                    title:
                                                        const Text('Send File'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      pickFile(
                                                          'file',
                                                          _userBox,
                                                          widget.user.id,
                                                          _scrollToBottom,
                                                          showSnackbar);
                                                    },
                                                  ),
                                                ],
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
                                    ),
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
