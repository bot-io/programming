// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsEntityAdapter extends TypeAdapter<SettingsEntity> {
  @override
  final int typeId = 1;

  @override
  SettingsEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingsEntity(
      themeMode: fields[0] as ThemeMode,
      fontlFamily: fields[1] as String,
      fontSize: fields[2] as double,
      lineHeight: fields[3] as double,
      margin: fields[4] as double,
      textAlign: fields[5] as TextAlign,
      panelWidthRatio: fields[6] as double,
      targetTranslationLanguageCode: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsEntity obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.fontlFamily)
      ..writeByte(2)
      ..write(obj.fontSize)
      ..writeByte(3)
      ..write(obj.lineHeight)
      ..writeByte(4)
      ..write(obj.margin)
      ..writeByte(5)
      ..write(obj.textAlign)
      ..writeByte(6)
      ..write(obj.panelWidthRatio)
      ..writeByte(7)
      ..write(obj.targetTranslationLanguageCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
