import 'package:airchat/models/chat_message.dart';
import 'package:airchat/models/chat_user.dart';
import 'package:airchat/services/connection_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

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
      await ConnectionService.sendFile(id, userId, picked.path, picked.name);
      // Send image file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
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
      // Send video file via Nearby
      String id = DateTime.now().toIso8601String();
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
        mimeType: 'video/${picked.path.split('.').last}',
      );
      user.messages.add(msg);
      user.save();
      await ConnectionService.sendFile(id, userId, picked.path, picked.name);
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
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
      final msg = ChatMessage(
        id: id,
        senderId: 'me',
        text: '',
        timestamp: DateTime.now(),
        isMe: true,
        isRead: true,
        type: type,
        fileName: result.files.single.name,
        filePath: result.files.single.path,
        mimeType: result.files.single.extension != null
            ? 'application/${result.files.single.extension}'
            : null,
      );
      user.messages.add(msg);
      user.save();
      await ConnectionService.sendFile(
          id, userId, result.files.single.path!, result.files.single.name);
      // Send file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
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
      await ConnectionService.sendFile(id, userId, picked.path, picked.name);
      // Send image file via Nearby
      WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error opening camera: $e');
    }
    showSnackbar('Failed to open camera: $e');
  }
}

