import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeProvider manages the app's theme state (dark/light mode)
/// and persists the user's theme preference.
class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  /// Initialize the theme provider by loading saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      
      if (savedTheme != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedTheme,
          orElse: () => ThemeMode.system,
        );
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // If loading fails, use system default
      _themeMode = ThemeMode.system;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Switch to dark theme
  Future<void> setDarkMode() async {
    if (_themeMode == ThemeMode.dark) return;
    
    _themeMode = ThemeMode.dark;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Switch to light theme
  Future<void> setLightMode() async {
    if (_themeMode == ThemeMode.light) return;
    
    _themeMode = ThemeMode.light;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Switch to system theme (follows device theme)
  Future<void> setSystemMode() async {
    if (_themeMode == ThemeMode.system) return;
    
    _themeMode = ThemeMode.system;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Toggle between dark and light theme
  /// If currently in system mode, switches to dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setLightMode();
    } else if (_themeMode == ThemeMode.light) {
      await setDarkMode();
    } else {
      // If system mode, check system brightness and toggle accordingly
      await setDarkMode();
    }
  }

  /// Save theme preference to persistent storage
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.toString());
    } catch (e) {
      // Silently fail if saving preference fails
      // Theme will still work for current session
    }
  }

  /// Get the appropriate ThemeData based on current theme mode and brightness
  ThemeData getThemeData(BuildContext context) {
    final brightness = _getBrightness(context);
    
    if (brightness == Brightness.dark) {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
    } else {
      return ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );
    }
  }

  /// Get the current brightness based on theme mode
  Brightness _getBrightness(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }
}
