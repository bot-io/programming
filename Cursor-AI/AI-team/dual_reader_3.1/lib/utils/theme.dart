import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class AppTheme {
  static ThemeData getTheme(String themeName) {
    switch (themeName) {
      case 'light':
        return _lightTheme;
      case 'sepia':
        return _sepiaTheme;
      case 'dark':
      default:
        return _darkTheme;
    }
  }

  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: const Color(0xFF1E1E1E),
      surfaceVariant: const Color(0xFF2D2D2D),
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white70,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
  );

  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      surfaceVariant: const Color(0xFFF5F5F5),
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black87,
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  static final ThemeData _sepiaTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF8B6914),
      secondary: const Color(0xFFA67C52),
      surface: const Color(0xFFF4E4BC),
      surfaceVariant: const Color(0xFFE8D5A3),
      onSurface: const Color(0xFF3E2723),
      onSurfaceVariant: const Color(0xFF5D4037),
    ),
    scaffoldBackgroundColor: const Color(0xFFF4E4BC),
  );
}
