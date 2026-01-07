import 'dart:convert';
import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 4)
class AppSettings {
  @HiveField(0)
  final String theme; // 'dark', 'light', 'sepia'

  @HiveField(1)
  final String fontFamily;

  @HiveField(2)
  final int fontSize; // 12-24

  @HiveField(3)
  final double lineHeight; // 1.0-2.5

  @HiveField(4)
  final int marginSize; // 0-4 (small to large)

  @HiveField(5)
  final String textAlignment; // 'left', 'center', 'justify'

  @HiveField(6)
  final String translationLanguage; // Target language code (e.g., 'es', 'fr')

  @HiveField(7)
  final bool autoTranslate;

  @HiveField(8)
  final double panelRatio; // 0.0-1.0 (landscape mode panel width ratio)

  @HiveField(9)
  final bool syncScrolling;

  AppSettings({
    this.theme = 'dark',
    this.fontFamily = 'Roboto',
    this.fontSize = 16,
    this.lineHeight = 1.6,
    this.marginSize = 2,
    this.textAlignment = 'left',
    this.translationLanguage = 'es',
    this.autoTranslate = true,
    this.panelRatio = 0.5,
    this.syncScrolling = true,
  });

  AppSettings copyWith({
    String? theme,
    String? fontFamily,
    int? fontSize,
    double? lineHeight,
    int? marginSize,
    String? textAlignment,
    String? translationLanguage,
    bool? autoTranslate,
    double? panelRatio,
    bool? syncScrolling,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      marginSize: marginSize ?? this.marginSize,
      textAlignment: textAlignment ?? this.textAlignment,
      translationLanguage: translationLanguage ?? this.translationLanguage,
      autoTranslate: autoTranslate ?? this.autoTranslate,
      panelRatio: panelRatio ?? this.panelRatio,
      syncScrolling: syncScrolling ?? this.syncScrolling,
    );
  }

  /// Convert settings to JSON map
  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'marginSize': marginSize,
      'textAlignment': textAlignment,
      'translationLanguage': translationLanguage,
      'autoTranslate': autoTranslate,
      'panelRatio': panelRatio,
      'syncScrolling': syncScrolling,
    };
  }

  /// Create settings from JSON map
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      theme: json['theme'] as String? ?? 'dark',
      fontFamily: json['fontFamily'] as String? ?? 'Roboto',
      fontSize: json['fontSize'] as int? ?? 16,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      marginSize: json['marginSize'] as int? ?? 2,
      textAlignment: json['textAlignment'] as String? ?? 'left',
      translationLanguage: json['translationLanguage'] as String? ?? 'es',
      autoTranslate: json['autoTranslate'] as bool? ?? true,
      panelRatio: (json['panelRatio'] as num?)?.toDouble() ?? 0.5,
      syncScrolling: json['syncScrolling'] as bool? ?? true,
    );
  }

  /// Convert settings to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Create settings from JSON string
  factory AppSettings.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (e) {
      // Return default settings if parsing fails
      return AppSettings();
    }
  }
}
