// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookEntityAdapter extends TypeAdapter<BookEntity> {
  @override
  final int typeId = 0;

  @override
  BookEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookEntity(
      id: fields[0] as String,
      title: fields[1] as String,
      author: fields[2] as String,
      coverPath: fields[3] as String,
      filePath: fields[4] as String,
      importedDate: fields[5] as DateTime,
      currentPage: fields[6] as int,
      totalPages: fields[7] as int,
      paginationStatus: fields[8] as int?,
      paginationProgress: fields[9] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, BookEntity obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.coverPath)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.importedDate)
      ..writeByte(6)
      ..write(obj.currentPage)
      ..writeByte(7)
      ..write(obj.totalPages)
      ..writeByte(8)
      ..write(obj.paginationStatus)
      ..writeByte(9)
      ..write(obj.paginationProgress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
