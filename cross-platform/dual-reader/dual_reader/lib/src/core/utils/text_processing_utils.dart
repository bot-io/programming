import 'package:flutter/foundation.dart';
import 'package:dual_reader/src/core/utils/sentence_splitter.dart';

/// Text processing utilities for paragraph-level context translation.
///
/// Provides intelligent sentence grouping, dialogue detection,
/// formatting preservation, and post-processing capabilities.
class TextProcessingUtils {
  // Private constructor to prevent instantiation
  TextProcessingUtils._();

  /// Maximum sentences to translate together for context.
  /// Too many = loss of context, too few = choppy translation
  static const int _maxSentencesPerGroup = 3;

  /// Minimum sentences per group (unless sentence is very long)
  static const int _minSentencesPerGroup = 1;

  /// Maximum characters per translation group
  /// Prevents token limit issues with translation models
  static const int _maxCharsPerGroup = 500;

  /// Group sentences intelligently for translation.
  ///
  /// Groups 2-3 sentences together when they form coherent units,
  /// respects dialogue boundaries, and maintains context flow.
  static List<SentenceGroup> groupSentencesForTranslation(List<String> sentences) {
    if (sentences.isEmpty) return [];

    final groups = <SentenceGroup>[];
    int currentStart = 0;

    while (currentStart < sentences.length) {
      final group = _findOptimalGroup(sentences, currentStart);
      groups.add(group);
      currentStart += group.sentences.length;
    }

    debugPrint('[TextProcessing] Grouped ${sentences.length} sentences into ${groups.length} groups');
    return groups;
  }

  /// Find the optimal group of sentences starting from the given index.
  static SentenceGroup _findOptimalGroup(List<String> sentences, int startIndex) {
    final groupSentences = <String>[];
    int currentLength = 0;
    int sentenceCount = 0;
    bool inDialogue = false;

    for (int i = startIndex; i < sentences.length; i++) {
      final sentence = sentences[i];

      // Check if sentence contains dialogue
      final hasDialogue = _containsDialogue(sentence);

      // If we're in dialogue, continue grouping dialogue lines
      if (inDialogue && hasDialogue) {
        groupSentences.add(sentence);
        currentLength += sentence.length;
        sentenceCount++;
        continue;
      }

      // End dialogue group if next sentence doesn't have dialogue
      if (inDialogue && !hasDialogue) {
        inDialogue = false;
        break;
      }

      // Start dialogue group
      if (hasDialogue && !inDialogue) {
        if (groupSentences.isNotEmpty) {
          // Start new group for dialogue
          break;
        }
        inDialogue = true;
      }

      // Check group size limits
      if (sentenceCount >= _maxSentencesPerGroup) {
        break;
      }

      final newLength = currentLength + sentence.length;
      if (newLength > _maxCharsPerGroup && sentenceCount >= _minSentencesPerGroup) {
        break;
      }

      groupSentences.add(sentence);
      currentLength = newLength;
      sentenceCount++;

      // Check for natural break points
      if (_isNaturalBreakPoint(sentence, i < sentences.length - 1 ? sentences[i + 1] : null)) {
        break;
      }
    }

    return SentenceGroup(
      sentences: groupSentences,
      isEmpty: false,
      isDialogue: inDialogue,
    );
  }

  /// Check if a sentence contains dialogue (quotes).
  static bool _containsDialogue(String sentence) {
    return RegExp(r'''["'].*["']''').hasMatch(sentence) ||
           RegExp(r'''["'][^"']*["']''').hasMatch(sentence);
  }

  /// Check if this is a natural break point between sentences.
  static bool _isNaturalBreakPoint(String current, String? next) {
    if (next == null) return true;

    // Break before chapter headers or time skips
    if (RegExp(r'^(Chapter|Part|Section|Book \d+)', caseSensitive: false).hasMatch(next)) {
      return true;
    }

    // Break before scene changes (often indicated by ...)
    if (current.trim().endsWith('...') || current.trim().endsWith('…')) {
      return true;
    }

    // Break after concluding words
    if (RegExp(r'\b(therefore|however|consequently|thus|meanwhile)\b', caseSensitive: false).hasMatch(next)) {
      return true;
    }

    return false;
  }

  /// Detect and extract dialogue patterns from text.
  ///
  /// Returns information about dialogue lines for consistent translation.
  static List<DialogueLine> detectDialogue(List<String> sentences) {
    final dialogues = <DialogueLine>[];

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];

      // Detect dialogue patterns
      final quoteMatch = RegExp(r'''["']([^"']+)["']''').firstMatch(sentence);
      if (quoteMatch != null) {
        final speakerMatch = RegExp(r'^(\w+)\s+(said|asked|replied|answered|exclaimed|whispered|shouted|murmured)', caseSensitive: false)
            .firstMatch(sentence);

        dialogues.add(DialogueLine(
          sentenceIndex: i,
          quote: quoteMatch.group(1)!,
          speaker: speakerMatch?.group(1),
          tag: speakerMatch?.group(2),
        ));
      }
    }

    return dialogues;
  }

  /// Extract formatting markers from text.
  ///
  /// Detects markdown-style formatting: **bold**, *italic*, `code`, [links](url)
  static List<FormattingMarker> extractFormatting(String text) {
    final markers = <FormattingMarker>[];

    // Bold: **text**
    final boldRegex = RegExp(r'\*\*([^*]+)\*\*');
    for (final match in boldRegex.allMatches(text)) {
      markers.add(FormattingMarker(
        type: FormattingType.bold,
        start: match.start,
        end: match.end,
        content: match.group(1)!,
      ));
    }

    // Italic: *text*
    final italicRegex = RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)');
    for (final match in italicRegex.allMatches(text)) {
      // Don't duplicate if already marked as bold
      if (!_isOverlapping(markers, match.start, match.end)) {
        markers.add(FormattingMarker(
          type: FormattingType.italic,
          start: match.start,
          end: match.end,
          content: match.group(1)!,
        ));
      }
    }

    // Code: `text`
    final codeRegex = RegExp(r'`([^`]+)`');
    for (final match in codeRegex.allMatches(text)) {
      if (!_isOverlapping(markers, match.start, match.end)) {
        markers.add(FormattingMarker(
          type: FormattingType.code,
          start: match.start,
          end: match.end,
          content: match.group(1)!,
        ));
      }
    }

    // Links: [text](url)
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in linkRegex.allMatches(text)) {
      if (!_isOverlapping(markers, match.start, match.end)) {
        markers.add(FormattingMarker(
          type: FormattingType.link,
          start: match.start,
          end: match.end,
          content: match.group(1)!,
          url: match.group(2),
        ));
      }
    }

    return markers;
  }

  /// Check if a range overlaps with existing markers.
  static bool _isOverlapping(List<FormattingMarker> markers, int start, int end) {
    for (final marker in markers) {
      if (start < marker.end && end > marker.start) {
        return true;
      }
    }
    return false;
  }

  /// Apply formatting markers to translated text.
  ///
  /// Attempts to preserve formatting by finding corresponding text
  /// in the translated version and applying markers.
  static String applyFormatting(String translatedText, List<FormattingMarker> originalMarkers) {
    if (originalMarkers.isEmpty) return translatedText;

    String result = translatedText;

    // Try to find and apply each marker
    // This is a best-effort approach as translation may change word order
    for (final marker in originalMarkers.reversed) {
      final pattern = marker.content;

      // Try to find the formatted content in translation
      final found = _findBestMatch(result, pattern);

      if (found != null) {
        final before = result.substring(0, found.start);
        final after = result.substring(found.end);
        final formatted = _applyMarkerStyle(result.substring(found.start, found.end), marker.type);

        result = before + formatted + after;
      }
    }

    return result;
  }

  /// Find the best matching position for text in translated string.
  static MatchPosition? _findBestMatch(String text, String pattern) {
    // Direct match
    final directIndex = text.indexOf(pattern);
    if (directIndex != -1) {
      return MatchPosition(directIndex, directIndex + pattern.length);
    }

    // Case-insensitive match
    final lowerText = text.toLowerCase();
    final lowerPattern = pattern.toLowerCase();
    final caseIndex = lowerText.indexOf(lowerPattern);
    if (caseIndex != -1) {
      return MatchPosition(caseIndex, caseIndex + pattern.length);
    }

    // Word-based fuzzy match
    final patternWords = pattern.split(RegExp(r'\s+'));
    if (patternWords.isEmpty) return null;

    int bestStart = -1;
    int bestMatchCount = 0;

    for (int i = 0; i < text.length - pattern.length; i++) {
      final window = text.substring(i, i + pattern.length * 2);
      final windowWords = window.split(RegExp(r'\s+'));

      int matchCount = 0;
      for (final word in patternWords) {
        if (windowWords.any((w) => w.toLowerCase() == word.toLowerCase())) {
          matchCount++;
        }
      }

      if (matchCount > bestMatchCount) {
        bestMatchCount = matchCount;
        bestStart = i;
      }
    }

    if (bestMatchCount >= patternWords.length * 0.5) {
      // Found a reasonable match (at least 50% of words)
      return MatchPosition(bestStart, bestStart + pattern.length);
    }

    return null;
  }

  /// Apply formatting style to text.
  static String _applyMarkerStyle(String text, FormattingType type) {
    switch (type) {
      case FormattingType.bold:
        return '**$text**';
      case FormattingType.italic:
        return '*$text*';
      case FormattingType.code:
        return '`$text`';
      case FormattingType.link:
        return text; // Links need special handling
    }
  }

  /// Post-process translated text to fix common issues.
  ///
  /// Fixes:
  /// - Spacing around punctuation
  /// - Capitalization
  /// - Quotation marks for target language
  /// - Ellipsis normalization
  static String postProcess(String translatedText, String targetLanguage) {
    String result = translatedText;

    // Fix spacing before punctuation (common in some languages)
    result = _fixSpacingAroundPunctuation(result);

    // Fix capitalization after sentence endings
    result = _fixCapitalization(result);

    // Normalize quotation marks based on target language
    result = _normalizeQuotationMarks(result, targetLanguage);

    // Normalize ellipsis
    result = _normalizeEllipsis(result);

    // Fix double spaces
    result = result.replaceAll(RegExp(r'  +'), ' ');

    // Fix space before newlines
    result = result.replaceAll(RegExp(r' \n'), '\n');

    return result.trim();
  }

  /// Fix spacing around punctuation marks.
  static String _fixSpacingAroundPunctuation(String text) {
    // Remove space before punctuation
    var result = text.replaceAll(RegExp(r'\s+([.,!?:;)])'), r'\1');

    // Ensure space after punctuation (except for abbreviations)
    result = result.replaceAll(RegExp(r'([.!?])([A-Z])'), r'\1 \2');

    return result;
  }

  /// Fix capitalization after sentence endings.
  static String _fixCapitalization(String text) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    final fixed = sentences.map((sentence) {
      if (sentence.isEmpty) return sentence;

      // Capitalize first letter
      final firstChar = sentence[0];
      final rest = sentence.substring(1);

      if (firstChar.toLowerCase() != firstChar.toUpperCase()) {
        // It's a letter
        return firstChar.toUpperCase() + rest;
      }

      return sentence;
    });

    return fixed.join(' ');
  }

  /// Normalize quotation marks for target language.
  static String _normalizeQuotationMarks(String text, String targetLanguage) {
    // Languages that use specific quotation marks
    switch (targetLanguage.toLowerCase()) {
      case 'fr':
        // French: « ... »
        return text
            .replaceAll(RegExp(r'''\"([^"]+)\"'''), r'« $1 »')
            .replaceAll(RegExp(r"""'([^']+)'"""), r'« $1 »');
      case 'de':
      case 'cs':
      case 'pl':
      case 'ru':
      case 'bg':
      case 'uk':
        // German and Slavic: „...“ or „...»
        return text
            .replaceAll(RegExp(r'''\"([^"]+)\"'''), r'„$1“')
            .replaceAll(RegExp(r"""'([^']+)'"""), r'‚$1‘');
      case 'es':
      case 'it':
      case 'ca':
        // Spanish/Italian/Catalan: « ... »
        return text.replaceAll(RegExp(r'''\"([^"]+)\"'''), r'« $1 »');
      case 'ja':
        // Japanese: 「 ... 」
        return text
            .replaceAll(RegExp(r'''\"([^"]+)\"'''), r'「$1」')
            .replaceAll(RegExp(r"""'([^']+)'"""), r'『$1』');
      case 'zh':
      case 'ko':
        // Chinese/Korean: 「 ... 」
        return text.replaceAll(RegExp(r'''\"([^"]+)\"'''), r'「$1」');
      default:
        // Keep standard quotes
        return text;
    }
  }

  /// Normalize ellipsis to standard form.
  static String _normalizeEllipsis(String text) {
    return text
        .replaceAll(RegExp(r'\.{2,}'), '...')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'\. \. \.'), '...');
  }

  /// Calculate translation quality score.
  ///
  /// Returns a score between 0 and 100 based on various metrics:
  /// - Length similarity with original
  /// - Sentence count preservation
  /// - Formatting preservation
  /// - Proper noun preservation
  static int calculateQualityScore(String original, String translated, String targetLanguage) {
    int score = 100;

    // Length similarity (should be within 50-200% of original)
    final lengthRatio = translated.length / original.length;
    if (lengthRatio < 0.5 || lengthRatio > 2.0) {
      score -= 20;
    } else if (lengthRatio < 0.75 || lengthRatio > 1.5) {
      score -= 10;
    }

    // Check for sentence endings
    final originalEndings = RegExp(r'[.!?]').allMatches(original).length;
    final translatedEndings = RegExp(r'[.!?]').allMatches(translated).length;

    if (translatedEndings < originalEndings * 0.8) {
      score -= 15;
    }

    // Check for proper noun preservation (capitalized words)
    final originalProper = RegExp(r'\b[A-Z][a-z]+\b').allMatches(original).length;
    final translatedProper = RegExp(r'\b[A-Z][a-z]+\b').allMatches(translated).length;

    if (translatedProper < originalProper * 0.5) {
      score -= 10;
    }

    // Check for preservation of numbers
    final originalNumbers = RegExp(r'\b\d+\b').allMatches(original).length;
    final translatedNumbers = RegExp(r'\b\d+\b').allMatches(translated).length;

    if (translatedNumbers < originalNumbers * 0.8) {
      score -= 10;
    }

    // Check for formatting preservation
    final originalFormatting = RegExp(r'[\*\`]').allMatches(original).length;
    final translatedFormatting = RegExp(r'[\*\`]').allMatches(translated).length;

    if (originalFormatting > 0 && translatedFormatting == 0) {
      score -= 5;
    }

    return score.clamp(0, 100);
  }

  /// Split text into contextual translation units.
  ///
  /// Combines sentence splitting with intelligent grouping
  /// and context preservation.
  static List<ContextualTranslationUnit> createTranslationUnits(String text) {
    // First split into sentences
    final sentences = SentenceSplitter.split(text);

    // Extract formatting before translation
    final formatting = TextProcessingUtils.extractFormatting(text);

    // Group sentences intelligently
    final groups = TextProcessingUtils.groupSentencesForTranslation(sentences);

    // Create translation units
    final units = <ContextualTranslationUnit>[];

    int sentenceOffset = 0;
    for (final group in groups) {
      final unitText = group.sentences.join(' ');

      // Find relevant formatting for this unit
      final unitFormatting = formatting.where((f) {
        return f.start >= sentenceOffset && f.end < sentenceOffset + unitText.length;
      }).toList();

      units.add(ContextualTranslationUnit(
        text: unitText,
        sentences: group.sentences,
        formatting: unitFormatting,
        isDialogue: group.isDialogue ?? false,
        startIndex: sentenceOffset,
      ));

      sentenceOffset += unitText.length + 1; // +1 for space
    }

    return units;
  }

  /// Reassemble translated units into complete text.
  static String reassembleTranslatedUnits(
    List<ContextualTranslationUnit> units,
    List<String> translations,
    String targetLanguage,
  ) {
    final buffer = StringBuffer();

    for (int i = 0; i < units.length; i++) {
      final unit = units[i];
      var translated = translations[i];

      // Apply formatting
      if (unit.formatting.isNotEmpty) {
        translated = TextProcessingUtils.applyFormatting(translated, unit.formatting);
      }

      // Post-process
      translated = TextProcessingUtils.postProcess(translated, targetLanguage);

      buffer.write(translated);

      // Add space between units if not ending with punctuation
      if (i < units.length - 1 && !RegExp(r'[.!?]$').hasMatch(translated)) {
        buffer.write(' ');
      }
    }

    return buffer.toString().trim();
  }
}

/// Represents a dialogue line for consistent translation.
class DialogueLine {
  final int sentenceIndex;
  final String quote;
  final String? speaker;
  final String? tag;

  DialogueLine({
    required this.sentenceIndex,
    required this.quote,
    this.speaker,
    this.tag,
  });

  bool get hasSpeaker => speaker != null;
  bool get hasTag => tag != null;
}

/// Formatting marker for preservation during translation.
class FormattingMarker {
  final FormattingType type;
  final int start;
  final int end;
  final String content;
  final String? url;

  FormattingMarker({
    required this.type,
    required this.start,
    required this.end,
    required this.content,
    this.url,
  });

  int get length => end - start;
}

/// Type of formatting.
enum FormattingType {
  bold,
  italic,
  code,
  link,
}

/// Position of a text match.
class MatchPosition {
  final int start;
  final int end;

  MatchPosition(this.start, this.end);
}

/// Contextual translation unit with formatting and metadata.
class ContextualTranslationUnit {
  final String text;
  final List<String> sentences;
  final List<FormattingMarker> formatting;
  final bool isDialogue;
  final int startIndex;

  ContextualTranslationUnit({
    required this.text,
    required this.sentences,
    required this.formatting,
    required this.isDialogue,
    required this.startIndex,
  });

  int get sentenceCount => sentences.length;
  int get length => text.length;
  bool hasFormatting => formatting.isNotEmpty;
}
