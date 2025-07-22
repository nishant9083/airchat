import 'dart:developer';
import 'dart:io';

import 'package:airchat/models/chat_message.dart';
import 'package:airchat/models/chat_user.dart';
import 'package:airchat/utility/audio_player.dart';
import 'package:airchat/utility/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

Widget getFileIcon(String? fileName) {
  if (fileName == null) {
    return Icon(Icons.insert_drive_file, color: Colors.blue[800]);
  }
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

String getFileType(String? fileName) {
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

String formatFileSize(String? filePath) {
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

Widget buildStatusLabel(ChatMessage msg) {
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

Widget getWidgetForMsg(ChatMessage msg, BuildContext context) {
  if (msg.type == 'image') {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          // margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: msg.isMe ? Theme.of(context).primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (!msg.isMe && msg.status != 1.0)
                ? SizedBox(
                    height: 180,
                    width: 180,
                  )
                : Image.file(
                    File(msg.filePath!),
                    width: 180,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Padding(
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
        if (msg.transferProgress != null && msg.status == 3)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
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
                          AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  } else if (msg.type == 'audio') {
    return KeepAliveMessageItem(
        child: Stack(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * (isMobile() ? 0.7 : 0.3),
          child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: msg.filePath != null && msg.status == 1
                  ? AudioPlayerWidget(filePath: msg.filePath!, isMe: msg.isMe)
                  : Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      decoration: BoxDecoration(
                          color: msg.isMe
                              ? Theme.of(context).primaryColor
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.audiotrack,
                              color: msg.isMe ? Colors.white : Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg.fileName ?? 'Audio',
                              style: TextStyle(
                                color: msg.isMe ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.only(top: 0.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: msg.transferProgress,
                      backgroundColor: Colors.white24,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
                )),
          )
      ],
    ));
  } else if (msg.type == 'video') {
    return KeepAliveMessageItem(
        child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 180,
          height: 180,
          // margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: msg.isMe
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (!msg.isMe && msg.status != 1.0)
                ? SizedBox(
                    height: 180,
                    width: 180,
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video thumbnail
                      VideoThumbnailWidget(filePath: msg.filePath!),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 48),
                      ),
                    ],
                  ),
          ),
        ),
        if (msg.transferProgress != null && msg.status == 3)
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
                        AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ),
            ),
          ),
      ],
    ));
  } else if (msg.type == 'file') {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          // padding: const EdgeInsets.all(2),
          // margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: msg.isMe
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * (isMobile() ? 0.7 : 0.3),
            child: ListTile(
                leading: getFileIcon(msg.fileName),
                title: Text(
                  msg.fileName ?? 'File',
                  style: TextStyle(
                      color: msg.isMe ? Colors.white : Colors.black87),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getFileType(msg.fileName),
                        style: TextStyle(
                          fontSize: 10,
                          color: msg.isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      msg.filePath != null
                          ? Text(
                              ' \u2022 ${formatFileSize(msg.filePath)}',
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    msg.isMe ? Colors.white70 : Colors.black54,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ])),
          ),
        ),
        if (msg.transferProgress != null && msg.status == 3)
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
                        AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  } else if (msg.type == 'call') {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        // width: MediaQuery.of(context).size.width * 0.5,
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        // clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isMobile()?0.5:0.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              msg.isMe ? Icons.call_made : Icons.call_received,
              color: msg.isMe ? Colors.indigo : Colors.green,
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
                            // color: Theme.of(context).primaryColor,
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
                        'Missed Voice call',
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
        ));
  } else {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Text(
        msg.text,
        style: TextStyle(
          color: msg.isMe
              ? Colors.white
              : Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }
}

String formatTime(DateTime dt) {
  final now = DateTime.now();
  if (now.difference(dt).inDays == 0) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  } else if (now.difference(dt).inDays == 1) {
    return 'Yesterday';
  } else {
    return "${dt.day}/${dt.month}/${dt.year}";
  }
}

bool isMobile() {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

class KeepAliveMessageItem extends StatefulWidget {
  final Widget child;
  const KeepAliveMessageItem({required this.child, super.key});

  @override
  KeepAliveMessageItemState createState() => KeepAliveMessageItemState();
}

class KeepAliveMessageItemState extends State<KeepAliveMessageItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

 // Helper to actually delete messages (and optionally media)
  Future<void> deleteMessages(
      {required bool deleteMedia,
      required List<ChatMessage> messagesToDelete,
      required ChatUser user}) async {
    for (var msg in List.of(messagesToDelete)) {
      if (deleteMedia &&
          (msg.type == 'image' ||
              msg.type == 'file' ||
              msg.type == 'audio' ||
              msg.type == 'video')) {
        // Try to delete the file from storage
        if (msg.filePath != null && msg.filePath!.isNotEmpty) {
          final file = File(msg.filePath!);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (e) {
              
                log('Failed to delete file: $e');              
            }
          }
        }
      }
      user.messages.removeWhere((m) => m.id == msg.id);
    }
    await user.save();    
  }



class AttachmentAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const AttachmentAction({super.key, 
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha:0.15),
            radius: 24,
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
