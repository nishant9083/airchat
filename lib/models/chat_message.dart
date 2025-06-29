import 'package:hive/hive.dart';
// import 'package:hive_flutter/hive_flutter.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 1)
class ChatMessage extends HiveObject {
  @HiveField(0)
  String senderId;

  @HiveField(1)
  String text;

  @HiveField(2)
  DateTime timestamp;

  @HiveField(3)
  bool isMe;

  @HiveField(4)
  bool isRead;

  @HiveField(5)
  String type; // 'text', 'image', 'file'

  @HiveField(6)
  String? fileName;

  @HiveField(7)
  String? filePath;

  @HiveField(8)
  String? mimeType;

  @HiveField(9)
  int id;

  @HiveField(10)
  double? transferProgress;

  @HiveField(11)
  int? status; // 1: success, 2: failure, 3: in_progress , 4: canceled

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = false,
    this.type = 'text',
    this.fileName,
    this.filePath,
    this.mimeType,
    this.transferProgress,
    this.status
  });
} 