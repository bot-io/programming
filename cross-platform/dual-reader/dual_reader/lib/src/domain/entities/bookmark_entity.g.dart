// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookmarkEntityAdapter extends TypeAdapter<BookmarkEntity> {
  @override
  final int typeId = 3;

  @override
  BookmarkEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookmarkEntity(
      id: fields[0] as String,
      bookId: fields[1] as String,
      pageIndex: fields[2] as int,
      label: fields[3] as String,
      createdAtMillis: fields[4] as int,
      chapterTitle: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BookmarkEntity obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.pageIndex)
      ..writeByte(3)
      ..write(obj.label)
      ..writeByte(4)
      ..write(obj.createdAtMillis)
      ..writeByte(5)
      ..write(obj.chapterTitle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
