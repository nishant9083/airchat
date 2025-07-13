// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[9] as String,
      senderId: fields[0] as String,
      text: fields[1] as String,
      timestamp: fields[2] as DateTime,
      isMe: fields[3] as bool,
      isRead: fields[4] as bool,
      type: fields[5] as String,
      fileName: fields[6] as String?,
      filePath: fields[7] as String?,
      mimeType: fields[8] as String?,
      transferProgress: fields[10] as double?,
      status: fields[11] as int?,
      duration: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.senderId)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.isMe)
      ..writeByte(4)
      ..write(obj.isRead)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.fileName)
      ..writeByte(7)
      ..write(obj.filePath)
      ..writeByte(8)
      ..write(obj.mimeType)
      ..writeByte(9)
      ..write(obj.id)
      ..writeByte(10)
      ..write(obj.transferProgress)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.duration);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
