import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Hive TypeAdapter for Flutter's TextAlign enum
class TextAlignAdapter extends TypeAdapter<TextAlign> {
  @override
  final int typeId = 101; // Unique typeId, different from ThemeMode (100)

  @override
  TextAlign read(BinaryReader reader) {
    final index = reader.readByte();
    return TextAlign.values[index];
  }

  @override
  void write(BinaryWriter writer, TextAlign obj) {
    writer.writeByte(obj.index);
  }
}
