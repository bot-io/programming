import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'settings_entity.g.dart';

/// Available theme presets
enum ThemePreset {
  standard,
  sepia,
  ocean,
  forest,
  midnight,
}

@HiveType(typeId: 1) // Using typeId 1, as 0 is for BookEntity
class SettingsEntity extends Equatable {
  @HiveField(0)
  final ThemeMode themeMode; // Light, Dark, System
  @HiveField(1)
  final String fontlFamily;
  @HiveField(2)
  final double fontSize;
  @HiveField(3)
  final double lineHeight;
  @HiveField(4)
  final double margin;
  @HiveField(5)
  final TextAlign textAlign;
  @HiveField(6)
  final double panelWidthRatio; // For dual-panel layout
  @HiveField(7)
  final String targetTranslationLanguageCode;
  @HiveField(8, defaultValue: 'standard')
  final String themePreset; // standard, sepia, ocean, forest, midnight

  const SettingsEntity({
    this.themeMode = ThemeMode.system,
    this.fontlFamily = 'Roboto',
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.margin = 16.0,
    this.textAlign = TextAlign.justify,
    this.panelWidthRatio = 0.5,
    this.targetTranslationLanguageCode = 'es',
    this.themePreset = 'standard',
  });

  /// Get the ThemePreset enum value
  ThemePreset get preset {
    return ThemePreset.values.firstWhere(
      (p) => p.name == themePreset,
      orElse: () => ThemePreset.standard,
    );
  }

  SettingsEntity copyWith({
    ThemeMode? themeMode,
    String? fontlFamily,
    double? fontSize,
    double? lineHeight,
    double? margin,
    TextAlign? textAlign,
    double? panelWidthRatio,
    String? targetTranslationLanguageCode,
    String? themePreset,
  }) {
    return SettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      fontlFamily: fontlFamily ?? this.fontlFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      margin: margin ?? this.margin,
      textAlign: textAlign ?? this.textAlign,
      panelWidthRatio: panelWidthRatio ?? this.panelWidthRatio,
      targetTranslationLanguageCode: targetTranslationLanguageCode ?? this.targetTranslationLanguageCode,
      themePreset: themePreset ?? this.themePreset,
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        fontlFamily,
        fontSize,
        lineHeight,
        margin,
        textAlign,
        panelWidthRatio,
        targetTranslationLanguageCode,
        themePreset,
      ];
}
