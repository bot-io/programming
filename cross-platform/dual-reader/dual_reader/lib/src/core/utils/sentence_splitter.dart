import 'package:flutter/foundation.dart';

/// Advanced sentence splitting utility for improved translation quality.
///
/// Handles complex edge cases:
/// - Abbreviations (Mr., Mrs., Dr., etc.)
/// - Decimal numbers (3.14, 99.9%)
/// - URLs and email addresses
/// - Quotes and parentheses
/// - Ellipsis (...)
/// - Code blocks and inline code
/// - Proper nouns detection
/// - Numbers and dates
///
/// Uses a rule-based approach with regex patterns to identify sentence boundaries
/// while preserving context and structure.
class SentenceSplitter {
  // Private constructor to prevent instantiation
  SentenceSplitter._();

  /// Common abbreviations that should NOT be treated as sentence endings
  static const List<String> _abbreviations = [
    // Titles
    'Mr', 'Mrs', 'Ms', 'Miss', 'Dr', 'Prof', 'Rev', 'Hon', 'Gen', 'Sen', 'Rep',
    'Sr', 'Jr', 'Sgt', 'Capt', 'Lt', 'Col', 'Adm', 'Maj', 'Brig', 'St',
    // Academic
    'PhD', 'MD', 'DO', 'DDS', 'DVM', 'JD', 'LLB', 'BA', 'BS', 'MA', 'MS',
    'MBA', 'MPH', 'RN', 'LPN', 'PA', 'NP',
    // Time
    'am', 'pm', 'AM', 'PM',
    // Common words
    'vs', 'etc', 'eg', 'ie', 'viz', 'i.e', 'e.g', 'etc.',
    // Organizations
    'Inc', 'Ltd', 'Corp', 'Co', 'LLC', 'PLC', 'GmbH', 'AG',
    // Technology
    'App', 'API', 'HTTP', 'HTTPS', 'FTP', 'URL', 'IP', 'UI', 'UX', 'SQL',
    // Measurements
    'cm', 'mm', 'km', 'mg', 'kg', 'lb', 'oz', 'ft', 'in', 'ml', 'l',
    // Common Latin
    'et', 'al', 'ad', 'hoc', 'per', 'se',
    // More
    'approx', 'est', 'min', 'max', 'avg', 'vol', 'no', 'nos', 'pp',
  ];

  /// Domain-specific abbreviations (can be extended)
  static const Map<String, List<String>> _domainAbbreviations = {
    'legal': ['plaintiff', 'defendant', 'attorney', 'vs'],
    'medical': ['diagnosis', 'symptom', 'treatment'],
    'business': ['CEO', 'CFO', 'CTO', 'COO', 'HR', 'PR', 'R&D'],
  };

  /// Patterns that should NOT be split even if they contain periods
  static List<RegExp> get _protectedPatterns => [
    // URLs
    RegExp(r'https?://[^\s]+'),
    RegExp(r'www\.[^\s]+'),
    // Email addresses
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    // Decimal numbers
    RegExp(r'\b\d+\.\d+\b'),
    RegExp(r'\b\d+\.\d+[%°]\b'),
    // Version numbers
    RegExp(r'\bv?\d+\.\d+\.\d+\b'),
    // IP addresses
    RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
    // File extensions
    RegExp(r'\b\w+\.(jpg|jpeg|png|gif|pdf|doc|docx|xls|xlsx|txt|html|css|js)\b'),
    // Time expressions
    RegExp(r'\b\d{1,2}:\d{2}\b'),
    RegExp(r'\b\d{1,2}:\d{2}\s?(am|pm|AM|PM)\b'),
    // Dates with periods
    RegExp(r'\b\d{1,2}\.\d{1,2}\.\d{2,4}\b'),
    // Ellipsis
    RegExp(r'\.{3,}'),
    // Abbreviations with periods
    RegExp(r'\b(?:[A-Z][a-z]?\.){2,}'),
  ];

  /// Patterns that indicate a real sentence boundary
  static List<RegExp> get _boundaryPatterns => [
    // Sentence ending punctuation followed by space and capital letter
    RegExp(r'[.!?]+\s+[A-Z]'),
    // Sentence ending punctuation followed by quote and capital letter
    RegExp(r'''[.!?]+\s*["'»]\s*[A-Z]'''),
    // Question mark or exclamation point followed by space
    RegExp(r'[!?]+\s+\w'),
    // Multiple sentence ending punctuation
    RegExp(r'[.!?]{2,}\s+\w'),
  ];

  /// Split text into sentences while preserving structure.
  ///
  /// Returns a list of sentences in order.
  /// Preserves original whitespace and formatting.
  static List<String> split(String text) {
    if (text.trim().isEmpty) {
      return [];
    }

    final sentences = <String>[];
    final buffer = StringBuffer();
    int i = 0;

    while (i < text.length) {
      final char = text[i];

      // Check for protected patterns (URLs, emails, decimals, etc.)
      if (_isProtectedPattern(text, i)) {
        final end = _findProtectedEnd(text, i);
        buffer.write(text.substring(i, end));
        i = end;
        continue;
      }

      // Check for sentence boundary
      if (_isSentenceBoundary(text, i)) {
        buffer.write(char);
        i++;

        // Include whitespace after boundary
        while (i < text.length && text[i].trim().isEmpty) {
          buffer.write(text[i]);
          i++;
        }

        // Save sentence if it has content
        if (buffer.toString().trim().isNotEmpty) {
          sentences.add(buffer.toString().trim());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
      i++;
    }

    // Add remaining content
    if (buffer.toString().trim().isNotEmpty) {
      sentences.add(buffer.toString().trim());
    }

    debugPrint('[SentenceSplitter] Split into ${sentences.length} sentences');
    return sentences;
  }

  /// Split text into sentences, then rejoin with original structure preserved.
  /// This is useful for translation where you want to translate sentence by sentence
  /// but maintain the original paragraph structure.
  static List<SentenceGroup> splitIntoGroups(String text) {
    // First split into paragraphs
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    final groups = <SentenceGroup>[];

    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        groups.add(SentenceGroup(sentences: [], isEmpty: true));
        continue;
      }

      final sentences = split(paragraph);
      groups.add(SentenceGroup(
        sentences: sentences,
        isEmpty: false,
        originalText: paragraph,
      ));
    }

    return groups;
  }

  /// Check if the position is within a protected pattern.
  static bool _isProtectedPattern(String text, int position) {
    for (final pattern in _protectedPatterns) {
      final match = pattern.matchAsPrefix(text.substring(position));
      if (match != null && match.start == 0) {
        return true;
      }
    }
    return false;
  }

  /// Find the end of a protected pattern starting at position.
  static int _findProtectedEnd(String text, int position) {
    for (final pattern in _protectedPatterns) {
      final match = pattern.matchAsPrefix(text.substring(position));
      if (match != null && match.start == 0) {
        return position + match.end.toInt();
      }
    }
    return position + 1;
  }

  /// Check if position is at a sentence boundary.
  static bool _isSentenceBoundary(String text, int position) {
    if (position >= text.length) return false;

    final char = text[position];

    // Must be sentence ending punctuation
    if (char != '.' && char != '!' && char != '?') {
      return false;
    }

    // Check for abbreviations before the period
    if (char == '.') {
      final wordBefore = _getWordBefore(text, position);
      if (_isAbbreviation(wordBefore)) {
        return false;
      }
    }

    // Check for boundary patterns after this position
    final remaining = text.substring(position);
    for (final pattern in _boundaryPatterns) {
      if (pattern.hasMatch(remaining)) {
        return true;
      }
    }

    // Check if followed by capital letter (likely a new sentence)
    if (position + 1 < text.length) {
      final nextChar = text[position + 1];
      if (nextChar.trim().isEmpty && position + 2 < text.length) {
        final afterSpace = text[position + 2];
        if (_isCapitalLetter(afterSpace)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Get the word before a position (for abbreviation checking).
  static String _getWordBefore(String text, int position) {
    final start = text.lastIndexOf(RegExp(r'\s'), position - 1);
    return text.substring(start + 1, position).toLowerCase();
  }

  /// Check if a word is a known abbreviation.
  static bool _isAbbreviation(String word) {
    final lowerWord = word.toLowerCase();

    // Check main abbreviation list
    for (final abbr in _abbreviations) {
      if (lowerWord == abbr.toLowerCase() || lowerWord == '${abbr.toLowerCase()}.') {
        return true;
      }
    }

    // Check domain-specific abbreviations
    for (final domainList in _domainAbbreviations.values) {
      for (final abbr in domainList) {
        if (lowerWord == abbr.toLowerCase()) {
          return true;
        }
      }
    }

    // Check for single letter followed by period (initials)
    if (RegExp(r'^[A-Z]\.?$').hasMatch(word)) {
      return true;
    }

    return false;
  }

  /// Check if character is a capital letter.
  static bool _isCapitalLetter(String char) {
    return RegExp(r'[A-Z\u00C0-\u00DE]').hasMatch(char);
  }

  /// Detect and return code blocks that should not be translated.
  static List<CodeBlock> detectCodeBlocks(String text) {
    final blocks = <CodeBlock>[];

    // Multi-line code blocks (```...```)
    final codeBlockRegex = RegExp(r'```([\s\S]*?)```');
    for (final match in codeBlockRegex.allMatches(text)) {
      blocks.add(CodeBlock(
        start: match.start,
        end: match.end,
        content: match.group(0)!,
        language: _extractLanguageSpecifier(match.group(1)!),
      ));
    }

    // Inline code (`...`)
    final inlineCodeRegex = RegExp(r'`([^`\n]+)`');
    for (final match in inlineCodeRegex.allMatches(text)) {
      // Don't duplicate if already in a multi-line block
      if (!_isInExistingBlock(blocks, match.start)) {
        blocks.add(CodeBlock(
          start: match.start,
          end: match.end,
          content: match.group(0)!,
          language: null,
        ));
      }
    }

    return blocks;
  }

  /// Check if position is within an existing code block.
  static bool _isInExistingBlock(List<CodeBlock> blocks, int position) {
    for (final block in blocks) {
      if (position >= block.start && position <= block.end) {
        return true;
      }
    }
    return false;
  }

  /// Extract language specifier from code block (e.g., ```dart → dart).
  static String? _extractLanguageSpecifier(String firstLine) {
    final trimmed = firstLine.trim();
    if (trimmed.isEmpty) return null;

    // Common language names
    final languages = ['dart', 'java', 'javascript', 'python', 'ruby', 'go',
                      'rust', 'cpp', 'c', 'html', 'css', 'sql', 'bash', 'json'];

    for (final lang in languages) {
      if (trimmed.toLowerCase().startsWith(lang)) {
        return lang;
      }
    }

    return null;
  }

  /// Detect proper nouns in text (simplified heuristic).
  static List<String> detectProperNouns(String text) {
    final nouns = <String>[];

    // Capitalized words not at sentence start
    final words = text.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length; i++) {
      final word = words[i];

      // Skip if at start of text or after sentence-ending punctuation
      if (i == 0) continue;

      final previousWord = words[i - 1];
      if (RegExp(r'[.!?]$').hasMatch(previousWord)) continue;

      // Check for capitalized word
      if (RegExp(r'^[A-Z][a-z]+$').hasMatch(word)) {
        // Skip common words
        if (!_isCommonWord(word.toLowerCase())) {
          nouns.add(word);
        }
      }
    }

    return nouns;
  }

  /// Check if word is too common to be a proper noun.
  static bool _isCommonWord(String word) {
    const commonWords = {
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'this', 'that', 'these', 'those',
    };
    return commonWords.contains(word);
  }

  /// Detect numbers and dates that should be preserved.
  static List<String> detectNumbersAndDates(String text) {
    final matches = <String>[];

    // Various number patterns
    final patterns = [
      RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'), // Dates: 12/31/2024
      RegExp(r'\b\d{1,2}-\d{1,2}-\d{2,4}\b'), // Dates: 12-31-2024
      RegExp(r'\b\d{1,2}\.\d{1,2}\.\d{2,4}\b'), // Dates: 31.12.2024
      RegExp(r'\b\d+\b'), // Plain numbers
      RegExp(r'\b\d{1,3}(,\d{3})*\b'), // Numbers with commas: 1,234
      RegExp(r'\b\d+%?\b'), // Percentages
      RegExp(r'\b\$?\d+(\.\d{2})?\b'), // Currency
      RegExp(r'\b\d+\s*(feet|miles|kilometers|meters|cm|mm)\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        matches.add(match.group(0)!);
      }
    }

    return matches;
  }
}

/// Represents a group of sentences from a single paragraph.
class SentenceGroup {
  final List<String> sentences;
  final bool isEmpty;
  final String? originalText;
  final bool? isDialogue;

  SentenceGroup({
    required this.sentences,
    required this.isEmpty,
    this.originalText,
    this.isDialogue,
  });

  /// Reconstruct the paragraph from translated sentences.
  String reconstruct(List<String> translatedSentences) {
    if (isEmpty) return '';
    if (translatedSentences.isEmpty) return originalText ?? '';

    // Join sentences with spaces (original punctuation is preserved)
    return translatedSentences.join(' ');
  }
}

/// Represents a code block that should not be translated.
class CodeBlock {
  final int start;
  final int end;
  final String content;
  final String? language;

  CodeBlock({
    required this.start,
    required this.end,
    required this.content,
    this.language,
  });

  bool get isInline => content.startsWith('`') && !content.startsWith('```');
  bool get isMultiline => content.startsWith('```');
}
