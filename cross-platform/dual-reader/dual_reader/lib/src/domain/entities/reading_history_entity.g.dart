part of 'reading_history_entity.dart';

class ReadingHistoryEntityAdapter extends TypeAdapter<ReadingHistoryEntity> {
  @override
  final int typeId = 4;

  @override
  ReadingHistoryEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReadingHistoryEntity(
      id: fields[0] as String,
      bookId: fields[1] as String,
      bookTitle: fields[2] as String,
      startPage: fields[3] as int,
      endPage: fields[4] as int,
      startedAtMillis: fields[5] as int,
      endedAtMillis: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingHistoryEntity obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.bookTitle)
      ..writeByte(3)
      ..write(obj.startPage)
      ..writeByte(4)
      ..write(obj.endPage)
      ..writeByte(5)
      ..write(obj.startedAtMillis)
      ..writeByte(6)
      ..write(obj.endedAtMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingHistoryEntityAdapter && typeId == other.typeId;
}
