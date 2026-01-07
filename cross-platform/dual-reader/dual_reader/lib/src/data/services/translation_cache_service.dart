import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class TranslationCacheService {
  static const String _boxName = 'translationCache';
  static const int _maxKeyLength = 255;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  Future<Box<String>> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  /// Generate a cache key from text and target language.
  /// Uses hash for long texts to avoid Hive's 255 character key limit.
  String _generateCacheKey(String text, String targetLanguage) {
    final combined = '${text}_$targetLanguage';
    if (combined.length > _maxKeyLength) {
      // Use SHA256 hash for long texts
      final bytes = utf8.encode(combined);
      final hash = sha256.convert(bytes);
      return 'trans_${hash.toString().substring(0, 32)}';
    }
    return combined;
  }

  Future<void> cacheTranslation(String originalText, String targetLanguage, String translatedText) async {
    final box = await _getBox();
    final key = _generateCacheKey(originalText, targetLanguage);
    await box.put(key, translatedText);
  }

  String? getCachedTranslation(String originalText, String targetLanguage) {
    if (!Hive.isBoxOpen(_boxName)) {
      return null; // Return null if not open yet, it will be cached later
    }
    final box = Hive.box<String>(_boxName);
    final key = _generateCacheKey(originalText, targetLanguage);
    return box.get(key);
  }
}

