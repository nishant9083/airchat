import 'package:airchat/models/chat_message.dart';
import 'package:airchat/models/chat_user.dart';
import 'package:airchat/services/connection_service.dart';
import 'package:airchat/utility/storage_helpers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

Future<String> _copyToAppDir(File file, String id, {String? ext}) async {
  final appDir = await getReceivedFilesDir();
  final originalFileName = p.basename(file.path);
  final fileName = originalFileName;
  final destPath = p.join(appDir, 'sent', fileName);
  await file.copy(destPath);
  return destPath;
}

Future<void> pickImage(
  Box<ChatUser> userBox,
  String userId,
  void Function() scrollToBottom,
  void Function(String message) showSnackbar,
) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final user = userBox.get(userId);
      if (user == null) return;
      String id = DateTime.now().toIso8601String();
      // Copy file to app directory
      final copiedPath = await _copyToAppDir(File(picked.path), id,
          ext: picked.path.split('.').last);
      final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'image',
          fileName: picked.name,
          filePath: copiedPath,
          mimeType: 'image/${picked.path.split('.').last}',
          transferProgress: 0,
          status: 3
          );          
      user.messages.add(msg);
      user.save();
      // Send image file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      ConnectionService.sendFile(id, userId, copiedPath, picked.name);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error picking image: $e');
    }
    showSnackbar('Failed to pick image: $e');
  }
}

Future<void> pickVideo(
  Box<ChatUser> userBox,
  String userId,
  void Function() scrollToBottom,
  void Function(String message) showSnackbar,
) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      final user = userBox.get(userId);
      if (user == null) return;
      String id = DateTime.now().toIso8601String();
      // Copy file to app directory
      final copiedPath = await _copyToAppDir(File(picked.path), id,
          ext: picked.path.split('.').last);
      final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'video',
          fileName: picked.name,
          filePath: copiedPath,
          mimeType: 'video/${picked.path.split('.').last}',
          transferProgress: 0,status: 3);
      user.messages.add(msg);
      user.save();
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      ConnectionService.sendFile(id, userId, copiedPath, picked.name);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error picking video: $e');
    }
    showSnackbar('Failed to pick video: $e');
  }
}

Future<void> pickFile(
  String type,
  Box<ChatUser> userBox,
  String userId,
  void Function() scrollToBottom,
  void Function(String message) showSnackbar,
) async {
  try {
    final result = await FilePicker.platform
        .pickFiles(type: type == 'audio' ? FileType.audio : FileType.any);
    if (result != null && result.files.single.path != null) {
      final user = userBox.get(userId);
      if (user == null) return;
      String id = DateTime.now().toIso8601String();
      final filePath = result.files.single.path!;
      final ext = result.files.single.extension;
      // Copy file to app directory
      final copiedPath = await _copyToAppDir(File(filePath), id, ext: ext);
      final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: type,
          fileName: result.files.single.name,
          filePath: copiedPath,
          mimeType: ext != null ? 'application/$ext' : null,
          transferProgress: 0,
          status: 3);
      user.messages.add(msg);
      user.save();
      // Send file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      ConnectionService.sendFile(
          id, userId, copiedPath, result.files.single.name);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error picking file: $e');
    }
    showSnackbar('Failed to pick file: $e');
  }
}

Future<void> openCamera(
  Box<ChatUser> userBox,
  String userId,
  void Function() scrollToBottom,
  void Function(String message) showSnackbar,
) async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      final user = userBox.get(userId);
      String id = DateTime.now().toIso8601String();
      if (user == null) return;
      // Copy file to app directory
      final copiedPath = await _copyToAppDir(File(picked.path), id,
          ext: picked.path.split('.').last);
      final msg = ChatMessage(
          id: id,
          senderId: 'me',
          text: '',
          timestamp: DateTime.now(),
          isMe: true,
          isRead: true,
          type: 'image',
          fileName: picked.name,
          filePath: copiedPath,
          mimeType: 'image/${picked.path.split('.').last}',
          transferProgress: 0,status: 3);
      user.messages.add(msg);
      user.save();
      // Send image file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      ConnectionService.sendFile(id, userId, copiedPath, picked.name);
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error opening camera: $e');
    }
    showSnackbar('Failed to open camera: $e');
  }
}
