 import 'dart:io';

import 'package:airchat/models/chat_message.dart';
import 'package:flutter/material.dart';

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
