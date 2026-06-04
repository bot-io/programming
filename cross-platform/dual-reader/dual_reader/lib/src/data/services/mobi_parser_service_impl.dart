import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/domain/services/mobi_parser_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html_unescape/html_unescape.dart';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';

/// Implementation of MOBI parser service
///
/// MOBI format structure:
/// - Palm Database format (PDB) header
/// - MOBI header with metadata
/// - Text content (often HTML-like markup)
/// - Images stored separately
///
/// Supports:
/// - MOBI 7 (standard Mobipocket)
/// - KF8 (Kindle Format 8)
/// - Basic AZW3 (Amazon Kindle format)
class MobiParserServiceImpl implements MobiParserService {
  static const String _componentName = 'MobiParserService';
  static const int _palmDbHeaderSize = 78;
  static const int _mobiHeaderSize = 232;
  static const int _exthHeaderSize = 12;

  // Magic numbers
  static const int _pdbMagic = 0x4F4B5354; // "TSKO" (little-endian "OKST")
  static const int _mobiMagic = 0x4D4F4249; // "MOBI"
  static const int _exthMagic = 0x45585448; // "EXTH"

  final HtmlUnescape _htmlUnescape = HtmlUnescape();

  // Parsed data cache
  String? _cachedText;
  List<ChapterEntity>? _cachedChapters;
  String? _cachedCoverPath;

  @override
  Future<MobiBookEntity> parseMobi(List<int> bytes) async {
    try {
      _componentName.logInfo('Parsing MOBI from ${bytes.length} bytes');

      // Validate minimum size
      if (bytes.length < _palmDbHeaderSize) {
        throw MobiParseException('File too small to be a valid MOBI');
      }

      // Check for DRM protection
      if (_isDrmProtected(bytes)) {
        throw const MobiDrmException(
          'This MOBI file is DRM-protected and cannot be opened. '
          'Please use a DRM-free version of this eBook.'
        );
      }

      // Parse Palm Database header
      final pdbHeader = _parsePalmHeader(bytes);
      _componentName.logDebug('PDB DB: ${pdbHeader['dbName']}');

      // Parse MOBI header
      final mobiHeader = _parseMobiHeader(bytes, pdbHeader['mobiOffset'] as int);
      _componentName.logDebug(
        'MOBI Header: version=${mobiHeader['version']}, '
        'title length=${mobiHeader['titleLength']}'
      );

      // Parse EXTH header if present
      final exthData = _parseExthHeader(bytes, mobiHeader);
      final metadata = _extractMetadata(exthData, mobiHeader);

      // Extract text content
      final fullText = await extractFullText(bytes);
      _componentName.logDebug('Extracted ${fullText.length} characters');

      // Parse chapters
      final chapters = await parseTableOfContents(bytes);

      // Extract cover image
      final coverImageBytes = _extractCoverImageBytes(bytes, mobiHeader);

      return MobiBookEntity(
        title: metadata['title'] ?? 'Unknown Title',
        author: metadata['author'] ?? 'Unknown Author',
        publisher: metadata['publisher'],
        description: metadata['description'],
        language: metadata['language'],
        isbn: metadata['isbn'],
        publishDate: metadata['publishDate'],
        chapters: chapters,
        coverImageBytes: coverImageBytes,
      );
    } on MobiDrmException {
      rethrow;
    } on MobiParseException {
      rethrow;
    } catch (e, stackTrace) {
      _componentName.logError('Failed to parse MOBI', error: e);
      debugPrint('[_MobiParser] Stack trace: $stackTrace');
      throw MobiParseException('Failed to parse MOBI file: ${e.toString()}', e);
    }
  }

  @override
  Future<String> extractCoverImage(List<int> bytes, String bookId) async {
    try {
      // Check cache first
      if (_cachedCoverPath != null) {
        return _cachedCoverPath!;
      }

      final mobiHeader = _parseMobiHeader(
        bytes,
        _findMobiOffset(bytes),
      );

      final coverBytes = _extractCoverImageBytes(bytes, mobiHeader);
      if (coverBytes == null || coverBytes.isEmpty) {
        _componentName.logInfo('No cover image found in MOBI');
        return '';
      }

      // Save to local storage
      if (kIsWeb) {
        _componentName.logDebug('Web platform: cover will be stored as base64');
        return '';
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDocDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final coverPath = '${coversDir.path}/$bookId.jpg';
      final file = File(coverPath);
      await file.writeAsBytes(coverBytes);

      _cachedCoverPath = coverPath;
      _componentName.logInfo('Cover image saved: $coverPath');

      return coverPath;
    } catch (e) {
      _componentName.logError('Failed to extract cover image', error: e);
      return '';
    }
  }

  @override
  Future<String> extractFullText(List<int> bytes) async {
    try {
      // Check cache
      if (_cachedText != null) {
        return _cachedText!;
      }

      final mobiOffset = _findMobiOffset(bytes);
      final mobiHeader = _parseMobiHeader(bytes, mobiOffset);

      // Get text content location
      final textOffset = mobiHeader['textOffset'] as int;
      final textLength = mobiHeader['textLength'] as int;

      if (textLength == 0 || textOffset + textLength > bytes.length) {
        throw MobiParseException('Invalid text content offsets in MOBI header');
      }

      // Extract raw text data
      final textBytes = bytes.sublist(textOffset, textOffset + textLength);
      final rawText = utf8.decode(textBytes, allowMalformed: true);

      // Convert MOBI markup to plain text
      final plainText = _mobiMarkupToPlainText(rawText);

      _cachedText = plainText;
      _componentName.logInfo('Extracted ${plainText.length} characters from MOBI');

      return plainText;
    } catch (e) {
      _componentName.logError('Failed to extract full text', error: e);
      rethrow;
    }
  }

  @override
  Future<List<ChapterEntity>> parseTableOfContents(List<int> bytes) async {
    try {
      // Check cache
      if (_cachedChapters != null) {
        return _cachedChapters!;
      }

      final mobiOffset = _findMobiOffset(bytes);
      final mobiHeader = _parseMobiHeader(bytes, mobiOffset);

      final chapters = <ChapterEntity>[];

      // Check if INDX (index) records exist for chapter navigation
      final hasIndex = mobiHeader['hasIndex'] == true;
      if (hasIndex) {
        final indexOffset = mobiHeader['indexOffset'] as int?;
        if (indexOffset != null && indexOffset > 0 && indexOffset < bytes.length) {
          final indexChapters = _parseIndexRecords(bytes, indexOffset);
          chapters.addAll(indexChapters);
        }
      }

      // Fallback: Split content into chapters based on common markers
      if (chapters.isEmpty) {
        final fullText = await extractFullText(bytes);
        final generatedChapters = _generateChaptersFromText(fullText);
        chapters.addAll(generatedChapters);
      }

      _cachedChapters = chapters;
      _componentName.logInfo('Parsed ${chapters.length} chapters from MOBI');

      return chapters;
    } catch (e) {
      _componentName.logError('Failed to parse TOC', error: e);
      // Return empty list rather than failing
      return [];
    }
  }

  /// Parse Palm Database header
  Map<String, dynamic> _parsePalmHeader(List<int> bytes) {
    try {
      final dbName = String.fromCharCodes(bytes.sublist(0, 32)).split('\x00')[0];
      final fileCount = _readUint16(bytes, 76);

      // Find MOBI record offset (usually first record)
      int mobiOffset = 0;
      for (int i = 0; i < fileCount && i < 10; i++) {
        final recordOffset = _readUint32(bytes, 78 + (i * 8));
        if (recordOffset > 0 && recordOffset < bytes.length) {
          // Check if this is the MOBI header
          if (recordOffset + 4 <= bytes.length) {
            final magic = _readUint32(bytes, recordOffset);
            if (magic == _mobiMagic) {
              mobiOffset = recordOffset;
              break;
            }
          }
        }
      }

      if (mobiOffset == 0) {
        throw MobiParseException('Could not find MOBI header in file');
      }

      return {
        'dbName': dbName,
        'fileCount': fileCount,
        'mobiOffset': mobiOffset,
      };
    } catch (e) {
      throw MobiParseException('Failed to parse Palm Database header: $e', e);
    }
  }

  /// Parse MOBI header
  Map<String, dynamic> _parseMobiHeader(List<int> bytes, int offset) {
    try {
      if (offset + _mobiHeaderSize > bytes.length) {
        throw MobiParseException('MOBI header extends beyond file bounds');
      }

      final magic = _readUint32(bytes, offset);
      if (magic != _mobiMagic) {
        throw MobiFormatException('Invalid MOBI magic number: 0x${magic.toRadixString(16)}');
      }

      final headerLength = _readUint32(bytes, offset + 4);
      final mobiType = _readUint32(bytes, offset + 8);
      final textEncoding = _readUint32(bytes, offset + 12);
      final uid = _readUint32(bytes, offset + 16);
      final version = _readUint32(bytes, offset + 20);

      final textOffset = _readUint32(bytes, offset + 36);
      final textLength = _readUint32(bytes, offset + 44);
      final textRecordCount = _readUint32(bytes, offset + 24);
      final textRecordSize = _readUint32(bytes, offset + 28);

      final exthFlags = _readUint32(bytes, offset + 128);
      final hasExth = (exthFlags & 0x40) != 0;

      // Full name offset
      final fullNameOffset = _readUint32(bytes, offset + 92);
      final fullNameLength = _readUint32(bytes, offset + 96);

      // Read full name (title)
      String? title;
      if (fullNameOffset > 0 && fullNameLength > 0 &&
          fullNameOffset + fullNameLength <= bytes.length) {
        title = utf8.decode(bytes.sublist(fullNameOffset, fullNameOffset + fullNameLength));
      }

      return {
        'magic': magic,
        'headerLength': headerLength,
        'mobiType': mobiType,
        'textEncoding': textEncoding,
        'uid': uid,
        'version': version,
        'textOffset': textOffset,
        'textLength': textLength,
        'textRecordCount': textRecordCount,
        'textRecordSize': textRecordSize,
        'hasExth': hasExth,
        'fullNameOffset': fullNameOffset,
        'fullNameLength': fullNameLength,
        'title': title,
        'titleLength': fullNameLength,
        'hasIndex': (exthFlags & 0x01) != 0,
        'indexOffset': _readUint32(bytes, offset + 144), // INDX offset
      };
    } catch (e) {
      throw MobiParseException('Failed to parse MOBI header: $e', e);
    }
  }

  /// Parse EXTH (Extended Metadata) header
  Map<String, String?> _parseExthHeader(List<int> bytes, Map<String, dynamic> mobiHeader) {
    final metadata = <String, String?>{};

    try {
      final hasExth = mobiHeader['hasExth'] as bool;
      if (!hasExth) {
        return metadata;
      }

      final mobiOffset = _findMobiOffset(bytes);
      final headerLength = mobiHeader['headerLength'] as int;
      int exthOffset = mobiOffset + headerLength;

      // Validate EXTH magic
      if (exthOffset + _exthHeaderSize > bytes.length) {
        return metadata;
      }

      final magic = _readUint32(bytes, exthOffset);
      if (magic != _exthMagic) {
        _componentName.logDebug('EXTH magic not found, skipping EXTH parsing');
        return metadata;
      }

      final headerLength = _readUint32(bytes, exthOffset + 4);
      final recordCount = _readUint32(bytes, exthOffset + 8);

      // Parse EXTH records
      int recordOffset = exthOffset + _exthHeaderSize;
      for (int i = 0; i < recordCount; i++) {
        if (recordOffset + 8 > bytes.length) break;

        final recordType = _readUint32(bytes, recordOffset);
        final recordLength = _readUint32(bytes, recordOffset + 4);

        if (recordLength > 8 && recordOffset + recordLength <= bytes.length) {
          final recordData = bytes.sublist(recordOffset + 8, recordOffset + recordLength);
          final recordValue = utf8.decode(recordData);

          // Map EXTH record types to metadata keys
          final key = _mapExthRecordType(recordType);
          if (key != null) {
            metadata[key] = recordValue;
          }

          _componentName.logDebug('EXTH record: type=$recordType, value=$recordValue');
        }

        recordOffset += recordLength;
      }
    } catch (e) {
      _componentName.logWarning('Error parsing EXTH header: $e');
    }

    return metadata;
  }

  /// Map EXTH record type to metadata key
  String? _mapExthRecordType(int recordType) {
    const typeMap = {
      100: 'author',
      101: 'publisher',
      103: 'description',
      106: 'publishedDate',
      109: 'isbn',
      503: 'title',
    };
    return typeMap[recordType];
  }

  /// Extract metadata from parsed headers
  Map<String, String?> _extractMetadata(
    Map<String, String?> exthData,
    Map<String, dynamic> mobiHeader,
  ) {
    final metadata = <String, String?>{};

    // Title from MOBI header or EXTH
    metadata['title'] = (mobiHeader['title'] as String?) ??
                       exthData['title'] ??
                       'Unknown Title';

    // Author from EXTH
    metadata['author'] = exthData['author'] ?? 'Unknown Author';

    // Other metadata from EXTH
    metadata['publisher'] = exthData['publisher'];
    metadata['description'] = exthData['description'];
    metadata['publishDate'] = exthData['publishedDate'];
    metadata['isbn'] = exthData['isbn'];

    return metadata;
  }

  /// Extract cover image bytes from MOBI
  List<int>? _extractCoverImageBytes(List<int> bytes, Map<String, dynamic> mobiHeader) {
    try {
      // Try to find cover image in EXTH records (record type 201)
      // This would require parsing image records from the MOBI file
      // For now, return null as cover extraction is complex
      _componentName.logDebug('Cover image extraction not fully implemented');
      return null;
    } catch (e) {
      _componentName.logWarning('Error extracting cover: $e');
      return null;
    }
  }

  /// Parse INDX (index) records for chapter navigation
  List<ChapterEntity> _parseIndexRecords(List<int> bytes, int indexOffset) {
    final chapters = <ChapterEntity>[];

    try {
      // INDX parsing is complex and varies by MOBI version
      // For now, return empty list
      _componentName.logDebug('INDX parsing not fully implemented');
    } catch (e) {
      _componentName.logWarning('Error parsing index records: $e');
    }

    return chapters;
  }

  /// Generate chapters from text content using common chapter markers
  List<ChapterEntity> _generateChaptersFromText(String text) {
    final chapters = <ChapterEntity>[];

    try {
      // Common chapter heading patterns
      final chapterPatterns = [
        RegExp(r'^Chapter\s+\d+[:\.\s]*(.+)$', multiLine: true, caseSensitive: false),
        RegExp(r'^CHAPTER\s+\d+[:\.\s]*(.+)$', multiLine: true),
        RegExp(r'^\d+\.\s+(.+)$', multiLine: true),
        RegExp(r'^Part\s+\d+[:\.\s]*(.+)$', multiLine: true, caseSensitive: false),
      ];

      final lines = text.split('\n');
      StringBuffer currentContent = StringBuffer();
      String? currentTitle;
      int chapterCount = 0;

      for (final line in lines) {
        final trimmedLine = line.trim();
        bool isChapterStart = false;

        // Check if this line is a chapter heading
        for (final pattern in chapterPatterns) {
          final match = pattern.firstMatch(trimmedLine);
          if (match != null) {
            // Save previous chapter
            if (currentTitle != null && currentContent.toString().isNotEmpty) {
              chapters.add(ChapterEntity(
                title: currentTitle,
                content: currentContent.toString().trim(),
                level: 0,
              ));
            }

            currentTitle = match.group(1)?.trim() ?? trimmedLine;
            currentContent = StringBuffer();
            isChapterStart = true;
            chapterCount++;
            break;
          }
        }

        if (!isChapterStart) {
          currentContent.writeln(line);
        }
      }

      // Add last chapter
      if (currentTitle != null && currentContent.toString().isNotEmpty) {
        chapters.add(ChapterEntity(
          title: currentTitle,
          content: currentContent.toString().trim(),
          level: 0,
        ));
      }

      // If no chapters were found, create a single chapter
      if (chapters.isEmpty && text.isNotEmpty) {
        chapters.add(ChapterEntity(
          title: 'Full Text',
          content: text,
          level: 0,
        ));
      }

      _componentName.logDebug('Generated $chapterCount chapters from text');
    } catch (e) {
      _componentName.logWarning('Error generating chapters: $e');
      // Fallback: single chapter
      if (text.isNotEmpty) {
        chapters.add(ChapterEntity(
          title: 'Full Text',
          content: text,
          level: 0,
        ));
      }
    }

    return chapters;
  }

  /// Convert MOBI markup to plain text
  String _mobiMarkupToPlainText(String markup) {
    try {
      // MOBI often contains HTML-like markup
      final document = html_parser.parse(markup);

      // Remove script and style elements
      document
          .querySelectorAll('script, style, meta, link')
          .forEach((element) => element.remove());

      // Get text content
      String text = document.body?.text ?? document.text ?? '';

      // HTML unescape
      text = _htmlUnescape.convert(text);

      // Clean up whitespace
      text = _sanitizeText(text);

      return text;
    } catch (e) {
      _componentName.logWarning('Error converting MOBI markup: $e');
      // Fallback: basic cleanup
      return _sanitizeMobiMarkupBasic(markup);
    }
  }

  /// Basic MOBI markup cleanup (fallback)
  String _sanitizeMobiMarkupBasic(String markup) {
    String text = markup;

    // Remove common MOBI/HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text.replaceAll(RegExp(r'&nbsp;'), ' ');
    text = text.replaceAll(RegExp(r'&amp;'), '&');
    text = text.replaceAll(RegExp(r'&lt;'), '<');
    text = text.replaceAll(RegExp(r'&gt;'), '>');
    text = text.replaceAll(RegExp(r'&quot;'), '"');
    text = text.replaceAll(RegExp(r'&#39;'), "'");

    // Remove MOBI-specific markup
    text = text.replaceAll(RegExp(r'<mbp:pagebreak[^>]*>'), '\n\n');
    text = text.replaceAll(RegExp(r'<[/?]?mbp:[^>]*>'), '');

    // Clean up whitespace
    text = _sanitizeText(text);

    return text.trim();
  }

  /// Clean up whitespace
  String _sanitizeText(String text) {
    // Replace multiple spaces with single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Replace multiple newlines with double newline
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    // Clean up spaces around newlines
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r' *'), ' ');

    return text.trim();
  }

  /// Check if MOBI is DRM-protected
  bool _isDrmProtected(List<int> bytes) {
    try {
      // Check for DRM indicators in the first part of the file
      final sampleSize = bytes.length > 10000 ? 10000 : bytes.length;
      final sample = String.fromCharCodes(bytes.sublist(0, sampleSize));

      // Common DRM indicators
      final drmPatterns = [
        'drm',
        'encryption',
        'protected',
        'pid',
        'kindle',
      ];

      final sampleLower = sample.toLowerCase();
      for (final pattern in drmPatterns) {
        // Check for DRM-related patterns
        if (sampleLower.contains('drm version') ||
            sampleLower.contains('drm-enabled') ||
            sampleLower.contains('drm protected')) {
          _componentName.logWarning('DRM pattern detected: $pattern');
          return true;
        }
      }

      // Check MOBI header for DRM bit
      final mobiOffset = _findMobiOffset(bytes);
      if (mobiOffset > 0 && mobiOffset + 128 <= bytes.length) {
        final exthFlags = _readUint32(bytes, mobiOffset + 128);
        // Bit 1 indicates DRM
        if ((exthFlags & 0x01) != 0) {
          // Check if it's just the index flag or actual DRM
          // This is a simplified check
          _componentName.logDebug('DRM flag set in MOBI header');
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Find MOBI header offset in the file
  int _findMobiOffset(List<int> bytes) {
    try {
      // Scan for MOBI magic number
      for (int i = 0; i < bytes.length - 4 && i < 10000; i++) {
        final value = _readUint32(bytes, i);
        if (value == _mobiMagic) {
          return i;
        }
      }
      throw MobiFormatException('Could not find MOBI header (magic number not found)');
    } catch (e) {
      throw MobiParseException('Failed to find MOBI offset: $e', e);
    }
  }

  /// Read 16-bit unsigned integer (little-endian)
  int _readUint16(List<int> bytes, int offset) {
    if (offset + 2 > bytes.length) return 0;
    return (bytes[offset] & 0xFF) |
           ((bytes[offset + 1] & 0xFF) << 8);
  }

  /// Read 32-bit unsigned integer (little-endian)
  int _readUint32(List<int> bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return (bytes[offset] & 0xFF) |
           ((bytes[offset + 1] & 0xFF) << 8) |
           ((bytes[offset + 2] & 0xFF) << 16) |
           ((bytes[offset + 3] & 0xFF) << 24);
  }
}