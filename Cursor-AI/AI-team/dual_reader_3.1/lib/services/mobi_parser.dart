import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart' as html_parser;
import '../models/book.dart';
import '../models/chapter.dart';
import 'storage_service.dart';

/// Basic MOBI file parser
/// MOBI files are based on the Palm Database (PDB) format
class MobiParser {
  final StorageService _storageService;

  MobiParser(this._storageService);

  /// Parse a MOBI file and extract book information
  Future<Book> parseMobi(String filePath, Uint8List? fileData) async {
    try {
      Uint8List bytes;
      
      if (kIsWeb && fileData != null) {
        bytes = fileData;
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('MOBI file not found: $filePath');
        }
        bytes = await file.readAsBytes();
      }

      if (bytes.length < 78) {
        throw Exception('File too small to be a valid MOBI file (minimum 78 bytes required)');
      }

      // Validate PDB header
      final pdbMagic = String.fromCharCodes(bytes.sublist(0, 4));
      if (pdbMagic != 'BOOK' && pdbMagic != 'MOBI' && pdbMagic != 'TEXt') {
        // Some MOBI files might have different magic numbers, continue anyway
        print('Warning: Unexpected PDB magic number: $pdbMagic');
      }

      // Read PDB header
      final pdbHeader = _readPdbHeader(bytes);
      
      if (pdbHeader.numRecords == 0) {
        throw Exception('Invalid MOBI file: no records found');
      }
      
      // Find MOBI record
      final mobiRecord = _findMobiRecord(bytes, pdbHeader);
      if (mobiRecord == null) {
        throw Exception('MOBI record not found in file. This may not be a valid MOBI file.');
      }

      if (mobiRecord.length < 16) {
        throw Exception('MOBI record too small to contain valid header');
      }

      // Parse MOBI header
      final mobiHeader = _parseMobiHeader(mobiRecord);
      
      // Extract metadata
      final title = _extractTitle(bytes, pdbHeader, mobiHeader) ?? 'Untitled';
      final author = _extractAuthor(bytes, pdbHeader, mobiHeader) ?? 'Unknown Author';
      final language = _extractLanguage(mobiHeader) ?? 'en';

      // Extract text content
      final textContent = _extractTextContent(bytes, pdbHeader, mobiHeader);
      if (textContent.isEmpty) {
        throw Exception('No text content found in MOBI file');
      }

      // Extract cover image
      String? coverImagePath;
      try {
        final coverData = _extractCoverImage(bytes, pdbHeader, mobiHeader);
        if (coverData != null && coverData.isNotEmpty) {
          final bookId = _generateBookId(title, author);
          coverImagePath = await _storageService.saveCoverImage(bookId, coverData);
        }
      } catch (e) {
        print('Error extracting cover image: $e');
        // Continue without cover image
      }

      // Generate bookId early for chapter references
      final bookId = _generateBookId(title, author);

      // Create chapters (MOBI files typically don't have explicit chapters, so we'll create one)
      final chapters = <Chapter>[];
      final cleanedText = _cleanText(textContent);
      
      // Try to split into chapters based on common patterns
      final chapterPatterns = [
        RegExp(r'\n\s*Chapter\s+\d+', caseSensitive: false),
        RegExp(r'\n\s*CHAPTER\s+\d+', caseSensitive: false),
        RegExp(r'\n\s*\d+\.\s+', caseSensitive: false),
        RegExp(r'\n\s*[IVX]+\.\s+', caseSensitive: false),
      ];

      int lastIndex = 0;
      int chapterIndex = 0;

      for (final pattern in chapterPatterns) {
        final matches = pattern.allMatches(cleanedText);
        if (matches.isNotEmpty) {
          for (final match in matches) {
            if (match.start > lastIndex) {
              final chapterTitle = cleanedText.substring(match.start, match.end).trim();
              chapters.add(Chapter(
                id: 'chapter_$chapterIndex',
                title: chapterTitle.isEmpty ? 'Chapter ${chapterIndex + 1}' : chapterTitle,
                startIndex: match.start,
                endIndex: match.end,
                startPage: 0, // Will be calculated during pagination
                endPage: 0, // Will be calculated during pagination
                bookId: bookId,
              ));
              chapterIndex++;
              lastIndex = match.end;
            }
          }
          break; // Use first pattern that finds matches
        }
      }

      // If no chapters found, create a single chapter
      if (chapters.isEmpty) {
        chapters.add(Chapter(
          id: 'chapter_0',
          title: 'Content',
          startIndex: 0,
          endIndex: cleanedText.length,
          startPage: 0, // Will be calculated during pagination
          endPage: 0, // Will be calculated during pagination
          bookId: bookId,
        ));
      } else {
        // Add final chapter end
        if (chapters.last.endIndex < cleanedText.length) {
          chapters.add(Chapter(
            id: 'chapter_$chapterIndex',
            title: 'Chapter ${chapterIndex + 1}',
            startIndex: chapters.last.endIndex,
            endIndex: cleanedText.length,
            startPage: 0, // Will be calculated during pagination
            endPage: 0, // Will be calculated during pagination
            bookId: bookId,
          ));
        }
      }

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        format: 'mobi',
        coverImagePath: coverImagePath,
        chapters: chapters,
        fullText: cleanedText,
        addedAt: DateTime.now(),
        language: language,
      );
    } catch (e) {
      throw Exception('Failed to parse MOBI file: $e');
    }
  }

  /// Read PDB header (first 78 bytes)
  _PdbHeader _readPdbHeader(Uint8List bytes) {
    final reader = _ByteReader(bytes);
    
    final name = reader.readString(32).trim();
    final attributes = reader.readUint16();
    final version = reader.readUint16();
    final createTime = reader.readUint32();
    final modifyTime = reader.readUint32();
    final backupTime = reader.readUint32();
    final modificationNumber = reader.readUint32();
    final appInfoId = reader.readUint32();
    final sortInfoId = reader.readUint32();
    final type = reader.readString(4);
    final creator = reader.readString(4);
    final uniqueIdSeed = reader.readUint32();
    final nextRecordListId = reader.readUint32();
    final numRecords = reader.readUint16();

    return _PdbHeader(
      name: name,
      numRecords: numRecords,
      type: type,
      creator: creator,
    );
  }

  /// Find MOBI record in PDB file
  Uint8List? _findMobiRecord(Uint8List bytes, _PdbHeader header) {
    final reader = _ByteReader(bytes);
    reader.offset = 78; // Skip PDB header

    // Read record list
    for (int i = 0; i < header.numRecords; i++) {
      final recordOffset = reader.readUint32();
      final recordAttributes = reader.readUint8();
      final recordUniqueId = reader.readUint24();

      if (recordOffset < bytes.length) {
        // Check if this looks like a MOBI header (starts with MOBI)
        final recordStart = recordOffset;
        if (recordStart + 4 < bytes.length) {
          final magic = String.fromCharCodes(bytes.sublist(recordStart, recordStart + 4));
          if (magic == 'MOBI') {
            // Read the record
            final recordLength = i < header.numRecords - 1
                ? (reader.peekUint32() - recordOffset)
                : (bytes.length - recordOffset);
            
            if (recordStart + recordLength <= bytes.length) {
              return bytes.sublist(recordStart, recordStart + recordLength);
            }
          }
        }
      }
    }

    return null;
  }

  /// Parse MOBI header
  _MobiHeader _parseMobiHeader(Uint8List mobiRecord) {
    final reader = _ByteReader(mobiRecord);
    
    final identifier = reader.readString(4); // Should be "MOBI"
    if (identifier != 'MOBI') {
      throw Exception('Invalid MOBI header identifier: $identifier');
    }
    
    final headerLength = reader.readUint32();
    if (headerLength < 16 || headerLength > mobiRecord.length) {
      throw Exception('Invalid MOBI header length: $headerLength');
    }
    
    final mobiType = reader.readUint32();
    final textEncoding = reader.readUint32();
    final uniqueId = reader.readUint32();
    final fileVersion = reader.readUint32();
    
    // Validate offsets before reading
    int titleOffset = 0;
    int titleLength = 0;
    int authorOffset = 0;
    int authorLength = 0;
    int languageCode = 0;
    int firstTextRecord = 0;
    int lastTextRecord = 0;
    
    // Try to read offsets if header is large enough
    if (headerLength >= 0x70) {
      try {
        reader.offset = 0x38; // Offset to title
        titleOffset = reader.readUint32();
        titleLength = reader.readUint32();
        
        reader.offset = 0x3C; // Offset to author
        authorOffset = reader.readUint32();
        authorLength = reader.readUint32();
        
        reader.offset = 0x44; // Offset to language
        languageCode = reader.readUint32();
        
        reader.offset = 0x68; // Offset to first text record
        firstTextRecord = reader.readUint32();
        
        reader.offset = 0x6C; // Offset to last text record
        lastTextRecord = reader.readUint32();
      } catch (e) {
        print('Warning: Could not read all MOBI header offsets: $e');
        // Use defaults
      }
    }

    return _MobiHeader(
      headerLength: headerLength,
      textEncoding: textEncoding,
      titleOffset: titleOffset,
      titleLength: titleLength,
      authorOffset: authorOffset,
      authorLength: authorLength,
      languageCode: languageCode,
      firstTextRecord: firstTextRecord,
      lastTextRecord: lastTextRecord,
    );
  }

  /// Extract title from MOBI file
  String? _extractTitle(Uint8List bytes, _PdbHeader pdbHeader, _MobiHeader mobiHeader) {
    if (mobiHeader.titleOffset == 0 || mobiHeader.titleLength == 0) {
      // Try to extract from PDB name as fallback
      if (pdbHeader.name.isNotEmpty && pdbHeader.name != 'Untitled') {
        return pdbHeader.name;
      }
      return null;
    }

    try {
      if (mobiHeader.titleOffset + mobiHeader.titleLength > bytes.length) {
        print('Warning: Title offset/length out of bounds');
        return null;
      }
      
      final titleBytes = bytes.sublist(
        mobiHeader.titleOffset,
        (mobiHeader.titleOffset + mobiHeader.titleLength).clamp(0, bytes.length),
      );
      
      if (mobiHeader.textEncoding == 65001) {
        // UTF-8
        return String.fromCharCodes(titleBytes);
      } else {
        // Latin-1 or other encoding
        return String.fromCharCodes(titleBytes);
      }
    } catch (e) {
      print('Error extracting title: $e');
      // Fallback to PDB name
      if (pdbHeader.name.isNotEmpty && pdbHeader.name != 'Untitled') {
        return pdbHeader.name;
      }
      return null;
    }
  }

  /// Extract author from MOBI file
  String? _extractAuthor(Uint8List bytes, _PdbHeader pdbHeader, _MobiHeader mobiHeader) {
    if (mobiHeader.authorOffset == 0 || mobiHeader.authorLength == 0) {
      return null;
    }

    try {
      if (mobiHeader.authorOffset + mobiHeader.authorLength > bytes.length) {
        print('Warning: Author offset/length out of bounds');
        return null;
      }
      
      final authorBytes = bytes.sublist(
        mobiHeader.authorOffset,
        (mobiHeader.authorOffset + mobiHeader.authorLength).clamp(0, bytes.length),
      );
      
      if (mobiHeader.textEncoding == 65001) {
        // UTF-8
        return String.fromCharCodes(authorBytes);
      } else {
        // Latin-1 or other encoding
        return String.fromCharCodes(authorBytes);
      }
    } catch (e) {
      print('Error extracting author: $e');
      return null;
    }
  }

  /// Extract language code
  String? _extractLanguage(_MobiHeader mobiHeader) {
    if (mobiHeader.languageCode == 0) {
      return null;
    }

    // Language codes are typically in format: lower 10 bits = primary, next 10 bits = region
    final primaryLang = mobiHeader.languageCode & 0x3FF;
    final region = (mobiHeader.languageCode >> 10) & 0x3FF;

    // Map common language codes
    final langMap = {
      9: 'en', // English
      10: 'fr', // French
      11: 'de', // German
      12: 'it', // Italian
      13: 'es', // Spanish
      14: 'pt', // Portuguese
      15: 'ru', // Russian
      16: 'ja', // Japanese
      17: 'zh', // Chinese
      18: 'ko', // Korean
    };

    return langMap[primaryLang] ?? 'en';
  }

  /// Extract text content from MOBI file
  String _extractTextContent(Uint8List bytes, _PdbHeader pdbHeader, _MobiHeader mobiHeader) {
    final textBuffer = StringBuffer();
    
    try {
      // MOBI text records start after the PDB header and record list
      final recordListSize = pdbHeader.numRecords * 8;
      final textStartOffset = 78 + recordListSize;
      
      // Read text records
      final reader = _ByteReader(bytes);
      reader.offset = 78; // Start of record list
      
      final textRecords = <int>[];
      for (int i = 0; i < pdbHeader.numRecords; i++) {
        final recordOffset = reader.readUint32();
        reader.readUint8(); // attributes
        reader.readUint24(); // uniqueId
        
        if (i >= mobiHeader.firstTextRecord && i <= mobiHeader.lastTextRecord) {
          textRecords.add(recordOffset);
        }
      }

      // Extract text from records
      for (int i = 0; i < textRecords.length; i++) {
        final recordOffset = textRecords[i];
        final recordEnd = i < textRecords.length - 1
            ? textRecords[i + 1]
            : bytes.length;
        
        if (recordOffset < bytes.length && recordEnd <= bytes.length) {
          final recordData = bytes.sublist(recordOffset, recordEnd);
          
          // Try to extract text (MOBI uses PalmDoc compression or HTML)
          final text = _extractTextFromRecord(recordData, mobiHeader.textEncoding);
          if (text.isNotEmpty) {
            textBuffer.write(text);
            if (i < textRecords.length - 1) {
              textBuffer.write('\n\n');
            }
          }
        }
      }
    } catch (e) {
      print('Error extracting text content: $e');
      // Fallback: try to extract any readable text
      return _extractTextFallback(bytes);
    }

    return textBuffer.toString();
  }

  /// Extract text from a single MOBI record
  String _extractTextFromRecord(Uint8List recordData, int encoding) {
    try {
      // Try PalmDoc decompression first
      final decompressed = _decompressPalmDoc(recordData);
      if (decompressed != null && decompressed.isNotEmpty) {
        // Extract HTML/text from decompressed data
        return _extractTextFromHtml(String.fromCharCodes(decompressed));
      }
      
      // Fallback: try direct text extraction
      if (encoding == 65001) {
        // UTF-8
        return _extractTextFromHtml(String.fromCharCodes(recordData));
      } else {
        // Latin-1
        return _extractTextFromHtml(String.fromCharCodes(recordData));
      }
    } catch (e) {
      // Last resort: try to find readable text
      return _extractReadableText(recordData);
    }
  }

  /// Decompress PalmDoc compressed data
  Uint8List? _decompressPalmDoc(Uint8List compressed) {
    if (compressed.isEmpty) return null;
    
    try {
      final decompressed = <int>[];
      int i = 0;
      
      while (i < compressed.length) {
        final byte = compressed[i];
        
        if (byte == 0x00) {
          // Literal null byte
          decompressed.add(0x20); // Convert to space
          i++;
        } else if (byte >= 0x01 && byte <= 0x08) {
          // Copy next N bytes literally
          final count = byte;
          i++;
          for (int j = 0; j < count && i < compressed.length; j++) {
            decompressed.add(compressed[i++]);
          }
        } else if (byte >= 0x09 && byte <= 0x7F) {
          // Literal byte
          decompressed.add(byte);
          i++;
        } else if (byte >= 0x80 && byte <= 0xBF) {
          // Space + literal byte
          decompressed.add(0x20);
          decompressed.add(byte & 0x7F);
          i++;
        } else if (byte >= 0xC0) {
          // Back reference
          if (i + 1 >= compressed.length) break;
          
          final high = byte & 0x3F;
          final low = compressed[i + 1];
          final distance = (high << 8) | low;
          final length = ((compressed[i + 1] >> 6) & 0x03) + 3;
          
          final startPos = decompressed.length - distance;
          if (startPos >= 0 && startPos < decompressed.length) {
            for (int j = 0; j < length && startPos + j < decompressed.length; j++) {
              decompressed.add(decompressed[startPos + j]);
            }
          }
          
          i += 2;
        } else {
          i++;
        }
      }
      
      return Uint8List.fromList(decompressed);
    } catch (e) {
      return null;
    }
  }

  /// Extract text from HTML content
  String _extractTextFromHtml(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      return document.body?.text ?? '';
    } catch (e) {
      // Fallback: remove HTML tags using regex
      return htmlContent
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// Fallback text extraction
  String _extractTextFallback(Uint8List bytes) {
    final text = StringBuffer();
    bool inText = false;
    
    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      if (byte >= 32 && byte <= 126) {
        // Printable ASCII
        text.writeCharCode(byte);
        inText = true;
      } else if (byte == 10 || byte == 13) {
        // Newline
        if (inText) {
          text.write('\n');
          inText = false;
        }
      } else if (byte == 9) {
        // Tab
        text.write(' ');
      }
    }
    
    return text.toString();
  }

  /// Extract readable text from bytes
  String _extractReadableText(Uint8List bytes) {
    final text = StringBuffer();
    for (final byte in bytes) {
      if (byte >= 32 && byte <= 126) {
        text.writeCharCode(byte);
      } else if (byte == 10 || byte == 13) {
        text.write('\n');
      } else if (byte == 9) {
        text.write(' ');
      }
    }
    return text.toString();
  }

  /// Extract cover image
  Uint8List? _extractCoverImage(Uint8List bytes, _PdbHeader pdbHeader, _MobiHeader mobiHeader) {
    // MOBI cover images are typically in image records
    // This is a simplified implementation
    // In a full implementation, you'd parse the EXTH header for cover image record index
    return null;
  }

  /// Clean extracted text
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll(RegExp(r'\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  String _generateBookId(String title, String author) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${title}_${author}_$timestamp'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}

/// Helper class for reading bytes
class _ByteReader {
  final Uint8List bytes;
  int offset = 0;

  _ByteReader(this.bytes);

  int readUint8() {
    if (offset >= bytes.length) return 0;
    return bytes[offset++];
  }

  int readUint16() {
    if (offset + 1 >= bytes.length) return 0;
    final value = (bytes[offset] << 8) | bytes[offset + 1];
    offset += 2;
    return value;
  }

  int readUint24() {
    if (offset + 2 >= bytes.length) return 0;
    final value = (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
    offset += 3;
    return value;
  }

  int readUint32() {
    if (offset + 3 >= bytes.length) return 0;
    final value = (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    offset += 4;
    return value;
  }

  String readString(int length) {
    if (offset + length > bytes.length) {
      length = bytes.length - offset;
    }
    final str = String.fromCharCodes(bytes.sublist(offset, offset + length));
    offset += length;
    return str;
  }

  int peekUint32() {
    final savedOffset = offset;
    final value = readUint32();
    offset = savedOffset;
    return value;
  }
}

/// PDB header structure
class _PdbHeader {
  final String name;
  final int numRecords;
  final String type;
  final String creator;

  _PdbHeader({
    required this.name,
    required this.numRecords,
    required this.type,
    required this.creator,
  });
}

/// MOBI header structure
class _MobiHeader {
  final int headerLength;
  final int textEncoding;
  final int titleOffset;
  final int titleLength;
  final int authorOffset;
  final int authorLength;
  final int languageCode;
  final int firstTextRecord;
  final int lastTextRecord;

  _MobiHeader({
    required this.headerLength,
    required this.textEncoding,
    required this.titleOffset,
    required this.titleLength,
    required this.authorOffset,
    required this.authorLength,
    required this.languageCode,
    required this.firstTextRecord,
    required this.lastTextRecord,
  });
}
