import 'dart:async';
import 'dart:io';
import 'package:airchat/utility/image_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

import '../utility/snackbar_util.dart';
import '../utility/video_viewer.dart';

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
  StreamSubscription? _fileTransferProgressSubscription;


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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ConnectionService.fileTransferProgressStream.listen((event) {
      final payloadId = event['payloadId'];
      final bytesTransferred = event['bytesTransferred'] as int?;
      final totalBytes = event['totalBytes'] as int?;      
      if (bytesTransferred != null && totalBytes != null && totalBytes > 0) {
        final progress = bytesTransferred / totalBytes;
        // Find the message being sent/received (by filePath or other means)
        final user = _userBox.get(widget.userId);
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

      final user = _userBox.get(widget.userId);
      if (user == null) return;

      final id = await ConnectionService.sendMessage(user.id, text);
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      showSnackbar('Failed to send message: $e');
    }
  }

  Future<void> _pickImage() async {
    try{
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final user = _userBox.get(widget.userId);
      if (user == null) return;
      int id = await ConnectionService.sendFile(
          widget.userId, picked.path, picked.name);
      final msg = ChatMessage(
        id: id,
        senderId: 'me',
        text: '',
        timestamp: DateTime.now(),
        isMe: true,
        isRead: true,
        type: 'image',
        fileName: picked.name,
        filePath: picked.path,
        mimeType: 'image/${picked.path.split('.').last}',
      );
      user.messages.add(msg);
      user.save();
      // Send image file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      showSnackbar('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final user = _userBox.get(widget.userId);
        if (user == null) return;
        // Send video file via Nearby
        int id = await ConnectionService.sendFile(
            widget.userId, picked.path, picked.name);
        final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'video',
          fileName: picked.name,
          filePath: picked.path,
          mimeType: 'video/${picked.path
              .split('.')
              .last}',
        );
        user.messages.add(msg);
        user.save();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    catch (e) {
      if (kDebugMode) {
        print('Error picking video: $e');
      }
      showSnackbar('Failed to pick video: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final user = _userBox.get(widget.userId);
        if (user == null) return;
        int id = await ConnectionService.sendFile(
            widget.userId, result.files.single.path!,
            result.files.single.name);
        final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'file',
          fileName: result.files.single.name,
          filePath: result.files.single.path,
          mimeType: result.files.single.extension != null
              ? 'application/${result.files.single.extension}'
              : null,
        );
        user.messages.add(msg);
        user.save();
        // Send file via Nearby
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    catch (e) {
      if (kDebugMode) {
        print('Error picking file: $e');
      }
      showSnackbar('Failed to pick file: $e');
    }
  }

  Future<void> _openCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final user = _userBox.get(widget.userId);
        int id = await ConnectionService.sendFile(
            widget.userId, picked.path, picked.name);
        if (user == null) return;
        final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'image',
          fileName: picked.name,
          filePath: picked.path,
          mimeType: 'image/${picked.path
              .split('.')
              .last}',
        );
        user.messages.add(msg);
        user.save();
        // Send image file via Nearby
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    catch (e) {
      if (kDebugMode) {
        print('Error opening camera: $e');
      }
      showSnackbar('Failed to open camera: $e');
    }
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
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _scrollToBottom());
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: user.messages.length,
                      itemBuilder: (context, index) {
                        final msg = user.messages[index];
                        // print(msg.filePath);
                        if (msg.type == 'image' &&
                            msg.filePath != null &&
                            File(msg.filePath!).existsSync()) {
                          return Column(
                            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: msg.isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () async {
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
                                          tag: msg.filePath, // Optional tag for Hero animation
                                        ),
                                        barrierDismissible: true
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: msg.isMe
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(msg.filePath!),
                                            width: 180,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: SizedBox(
                                                  width: 180,
                                                  height: 180,
                                                  child: Center(
                                                    child: Text(
                                                      'Image not found',
                                                      style: TextStyle(
                                                        color: msg.isMe ? Colors.white : Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ),
                                        ),
                                      ),
                                      if (msg.transferProgress != null && msg.transferProgress! < 1.0 && msg.status==3)
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black26,
                                            child: Center(
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: CircularProgressIndicator(
                                                  value: msg.transferProgress,
                                                  backgroundColor: Colors.white24,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildStatusLabel(msg),
                            ],
                          );
                        } else if (msg.type == 'video' &&
                            msg.filePath != null &&
                            File(msg.filePath!).existsSync()) {
                          return Column(
                            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: msg.isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: () async {
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
                                          tag: msg.filePath,
                                        ),
                                        barrierDismissible: true
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 180,
                                        height: 180,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: msg.isMe
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              // Video thumbnail
                                              VideoThumbnailWidget(filePath: msg.filePath!),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black45,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (msg.transferProgress != null && msg.transferProgress! < 1.0 && msg.status==3)
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black26,
                                            child: Center(
                                              child: SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: CircularProgressIndicator(
                                                  value: msg.transferProgress,
                                                  backgroundColor: Colors.white24,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildStatusLabel(msg),
                            ],
                          );
                        } else if (msg.type == 'file') {
                          return Column(
                            crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: msg.isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onTap: msg.filePath != null
                                      ? () async {
                                          final result =
                                              await OpenFile.open(msg.filePath!);
                                          if (result.type != ResultType.done) {
                                           if(context.mounted) {showSnackbar('Error: ${result.message}');}
                                          }
                                        }
                                      : null,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        // padding: const EdgeInsets.all(2),
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: msg.isMe
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: SizedBox(
                                          width: MediaQuery.of(context).size.width * 0.7,
                                          child: ListTile(
                                            leading: _getFileIcon(msg.fileName),
                                            title: Text(
                                              msg.fileName ?? 'File',
                                              style: TextStyle(
                                                  color: msg.isMe
                                                      ? Colors.white
                                                      : Colors.black87),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                            ),
                                            subtitle:Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                Text(
                                                _getFileType(msg.fileName),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: msg.isMe ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                          msg.filePath != null
                                              ? Text(
                                            ' \u2022 ${_formatFileSize(msg.filePath)}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: msg.isMe ? Colors.white70 : Colors.black54,
                                            ),
                                          )
                                                : const SizedBox.shrink(),])
                                          ),
                                        ),
                                      ),
                                      if (msg.transferProgress != null && msg.transferProgress! < 1.0 && msg.status==3)
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
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              _buildStatusLabel(msg),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                            ),
                            _buildStatusLabel(msg),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(18)
                          ),
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
                                                leading: const Icon(Icons.image),
                                                title: const Text('Send Image'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickImage();
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.video_collection),
                                                title: const Text('Send Video'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickVideo();
                                                },
                                              ),
                                              ListTile(
                                                leading:
                                                    const Icon(Icons.insert_drive_file),
                                                title: const Text('Send File'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _pickFile();
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
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                ),
                                onSubmitted: (_) => _sendMessage(),
                                enabled: isConnected,
                              ),
                            ),
                            IconButton(onPressed: isConnected?_openCamera:null,
                                icon: const Icon(Icons.camera_alt),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isConnected ? _sendMessage : null,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                      ),
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

  Widget _getFileIcon(String? fileName) {
    if (fileName == null) return Icon(Icons.insert_drive_file, color: Colors.blue[800]);

    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: Colors.red[700]);
      case 'doc':
      case 'docx':
        return Icon(Icons.description, color: Colors.blue[800]);
      case 'xls':
      case 'xlsx':
        return Icon(Icons.table_chart, color: Colors.green[700]);
      case 'ppt':
      case 'pptx':
        return Icon(Icons.slideshow, color: Colors.orange[700]);
      case 'txt':
        return Icon(Icons.article, color: Colors.blue[600]);
      case 'zip':
      case 'rar':
      case '7z':
        return Icon(Icons.archive, color: Colors.amber[700]);
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icon(Icons.audio_file, color: Colors.purple[600]);
      default:
        return Icon(Icons.insert_drive_file, color: Colors.blue[800]);
    }
  }

  String _getFileType(String? fileName) {
    if (fileName == null) return 'Unknown';

    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'bin':
        return 'BIN';
      case 'pdf':
        return 'PDF';
      case 'doc':
      case 'docx':
        return 'Word';
      case 'xls':
      case 'xlsx':
        return 'Excel';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint';
      case 'txt':
        return 'Txt';
      case 'zip':
      case 'rar':
      case '7z':
        return 'Archive';
      case 'mp3':
        return 'MP3';
      case 'wav':
        return 'WAV';
      case 'aac':
        return 'AAC';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Image';
      case 'mp4':
      case 'mkv':
      case 'mov':
        return 'Video';
      default:
        return extension.toUpperCase();
    }
  }
  String _formatFileSize(String? filePath) {
    if (filePath == null || !File(filePath).existsSync()) return '';

    final bytes = File(filePath).lengthSync();

    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Widget _buildStatusLabel(ChatMessage msg) {
    if (msg.status == 2) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
        child: Text(
          'Failed',
          style: TextStyle(
            color: Colors.red[700],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      );
    } else if (msg.status == 4) {
      return Padding(
        padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
        child: Text(
          'Cancelled',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
      );
    }
    // For status 3 (in_progress), progress loader is already shown
    // For status == null or 1 (success), show nothing
    return const SizedBox.shrink();
  }
}
