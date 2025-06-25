import 'package:hive/hive.dart';
import 'chat_message.dart';

part 'chat_user.g.dart';

@HiveType(typeId: 0)
class ChatUser extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime lastSeen;

  @HiveField(4)
  List<ChatMessage> messages;

  ChatUser({
    required this.id,
    required this.name,
    required this.lastSeen,
    required this.messages,
  });
} 