import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Hive TypeAdapter for Flutter's ThemeMode enum
class ThemeModeAdapter extends TypeAdapter<ThemeMode> {
  @override
  final int typeId = 100; // Unique typeId

  @override
  ThemeMode read(BinaryReader reader) {
    final index = reader.readByte();
    return ThemeMode.values[index];
  }

  @override
  void write(BinaryWriter writer, ThemeMode obj) {
    writer.writeByte(obj.index);
  }
}
