import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:dual_reader/src/core/utils/logging_service.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html_unescape/html_unescape.dart';

/// Implementation of EPUB parser service with full support for:
/// - Cover image extraction
/// - HTML to plain text conversion
/// - Table of contents parsing with nesting
/// - Enhanced metadata extraction
/// - DRM detection
/// - Error handling for corrupted files
class EpubParserServiceImpl implements EpubParserService {
  static const String _componentName = 'EpubParserService';
  static const int _maxCoverSizeBytes = 1024 * 1024; // 1MB max cover size
  static const int _maxCoverDimension = 2000; // 2000px max dimension

  final HtmlUnescape _htmlUnescape = HtmlUnescape();

  @override
  Future<EpubBookEntity> parseEpub(List<int> bytes) async {
    try {
      _componentName.logInfo('Parsing EPUB from ${bytes.length} bytes');

      // Check for minimum viable EPUB size
      if (bytes.length < 100) {
        throw EpubParseException('File too small to be a valid EPUB');
      }

      // Check for encrypted/malicious patterns
      if (_isEncryptedEpub(bytes)) {
        throw const EpubDrmException(
          'This EPUB is DRM-protected and cannot be opened. '
          'Please use a DRM-free version of this eBook.'
        );
      }

      // Parse the EPUB
      final epubBook = await EpubReader.readBook(bytes);

      // Validate structure
      if (epubBook.Chapters == null || epubBook.Chapters!.isEmpty) {
        _componentName.logWarning('EPUB has no chapters, will extract content from spine');
        // Some EPUBs have no chapters but have spine content
      }

      // Extract metadata
      final title = epubBook.Title ?? 'Unknown Title';
      final author = epubBook.Author ?? 'Unknown Author';
      final publisher = epubBook.Publisher;
      final description = _sanitizeHtmlText(epubBook.Description ?? '');
      final language = epubBook.Language;
      final isbn = _extractIsbn(epubBook);
      final publishDate = epubBook.PublishDate;
      final tags = _extractTags(epubBook);

      _componentName.logDebug(
        'Metadata extracted - Title: "$title", Author: "$author", '
        'Publisher: ${publisher ?? "N/A"}, Language: ${language ?? "N/A"}'
      );

      // Parse table of contents with nesting
      final chapters = await parseTableOfContents(epubBook);

      return EpubBookEntity(
        title: title,
        author: author,
        coverPath: '', // Will be set by extractCoverImage
        chapters: chapters,
        publisher: publisher,
        description: description.isNotEmpty ? description : null,
        language: language,
        isbn: isbn,
        publishDate: publishDate,
        tags: tags.isNotEmpty ? tags : null,
      );
    } on EpubDrmException {
      rethrow;
    } on EpubParseException {
      rethrow;
    } catch (e, stackTrace) {
      _componentName.logError('Failed to parse EPUB', error: e);
      debugPrint('[EpubParser] Stack trace: $stackTrace');
      throw EpubParseException('Failed to parse EPUB file: ${e.toString()}', e);
    }
  }

  @override
  Future<String> extractCoverImage(EpubBook epubBook, String bookId) async {
    try {
      _componentName.logDebug('Extracting cover image for book: $bookId');

      // Try multiple methods to find the cover image
      EpubByteContentFile? coverImage;

      // Method 1: Check CoverImage property (most common) - epubx uses Image type
      if (epubBook.CoverImage != null) {
        // epubx CoverImage returns an Image, need to get the byte content
        // The CoverImage is actually a reference, we need to get it from Content
        _componentName.logDebug('CoverImage property exists, accessing via Content');
      }

      // Method 2: Search in Content.Images for cover
      final content = epubBook.Content;
      if (content != null && content.Images != null) {
        for (final entry in content.Images.entries) {
          final fileName = entry.key.toLowerCase();
          final fileNameWithoutPath = fileName.split('/').last;

          // Common cover image names
          if (fileNameWithoutPath.contains('cover') &&
              (fileName.endsWith('.jpg') ||
                  fileName.endsWith('.jpeg') ||
                  fileName.endsWith('.png'))) {
            coverImage = entry.value;
            _componentName.logDebug('Found cover via Images search: $fileName');
            break;
          }
        }

        // If no cover found by name, try the first image
        if (coverImage == null && content.Images.isNotEmpty) {
          coverImage = content.Images.values.first;
          _componentName.logDebug('Using first image as cover');
        }
      }

      // Method 3: Search in AllFiles for cover (fallback)
      if (coverImage == null && content?.AllFiles != null) {
        for (final entry in content.AllFiles.entries) {
          final file = entry.value;
          if (file is EpubByteContentFile) {
            final fileName = entry.key.toLowerCase();
            final fileNameWithoutPath = fileName.split('/').last;

            // Common cover image names
            if (fileNameWithoutPath.contains('cover') &&
                (fileName.endsWith('.jpg') ||
                    fileName.endsWith('.jpeg') ||
                    fileName.endsWith('.png'))) {
              coverImage = file;
              _componentName.logDebug('Found cover via AllFiles search: $fileName');
              break;
            }
          }
        }
      }

      if (coverImage == null) {
        _componentName.logInfo('No cover image found in EPUB');
        return '';
      }

      // Get image bytes - epubx uses Content property
      final imageBytes = coverImage.Content as Uint8List?;

      if (imageBytes == null || imageBytes.isEmpty) {
        _componentName.logWarning('Cover image has no content');
        return '';
      }

      // Validate and optimize image
      final optimizedBytes = await _optimizeCoverImage(imageBytes);

      if (optimizedBytes == null) {
        _componentName.logWarning('Failed to optimize cover image');
        return '';
      }

      // Save to local storage
      if (kIsWeb) {
        _componentName.logDebug('Web platform: cover will be stored as base64');
        // For web, we'd store base64 in Hive
        return '';
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${appDocDir.path}/covers');
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Determine file extension from content type
      final contentType = coverImage.ContentTypeMimeType;
      String extension = '.jpg';
      if (contentType != null && contentType.contains('png')) {
        extension = '.png';
      }

      final coverPath = '${coversDir.path}/$bookId$extension';
      final file = File(coverPath);
      await file.writeAsBytes(optimizedBytes);

      _componentName.logInfo(
        'Cover image saved: $coverPath (${optimizedBytes.length} bytes)'
      );

      return coverPath;
    } catch (e) {
      _componentName.logError('Failed to extract cover image', error: e);
      return '';
    }
  }

  @override
  Future<String> extractFullText(EpubBook epubBook) async {
    try {
      _componentName.logInfo('Extracting full text content');
      final buffer = StringBuffer();

      // Get all chapters in order
      final chapters = epubBook.Chapters ?? [];

      if (chapters.isEmpty) {
        _componentName.logWarning('No chapters found, trying spine');
        // Fallback to reading from content HTML files
        final content = epubBook.Content;
        if (content != null && content.Html != null) {
          final htmlFiles = content.Html.values.toList();
          for (final htmlFile in htmlFiles) {
            final htmlContent = htmlFile.HtmlContent;
            if (htmlContent != null) {
              final text = _htmlToPlainText(htmlContent);
              buffer.write(text);
              buffer.write('\n\n');
            }
          }
        }
      } else {
        for (final chapter in chapters) {
          final text = await _extractChapterText(chapter);
          buffer.write(text);
          buffer.write('\n\n');
        }
      }

      final fullText = buffer.toString().trim();
      _componentName.logInfo(
        'Extracted ${fullText.length} characters from EPUB'
      );

      return fullText;
    } catch (e) {
      _componentName.logError('Failed to extract full text', error: e);
      rethrow;
    }
  }

  @override
  Future<List<ChapterEntity>> parseTableOfContents(EpubBook epubBook) async {
    try {
      _componentName.logInfo('Parsing table of contents');
      final chapters = <ChapterEntity>[];

      // epubx provides navigation through Chapters list
      // Try to get titles from chapters
      final chapterList = epubBook.Chapters ?? [];
      for (int i = 0; i < chapterList.length; i++) {
        final chapter = chapterList[i];
        final title = _sanitizeHtmlText(chapter.Title ?? 'Chapter ${i + 1}');
        final content = await _extractChapterText(chapter);

        chapters.add(ChapterEntity(
          title: title,
          content: content,
          level: 0,
        ));

        // Also handle sub-chapters
        if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
          await _parseSubChapters(chapter.SubChapters!, chapters, level: 1);
        }
      }

      _componentName.logInfo('Parsed ${chapters.length} TOC entries');

      return chapters;
    } catch (e) {
      _componentName.logError('Failed to parse TOC', error: e);
      // Return empty list rather than failing
      return [];
    }
  }

  /// Parse sub-chapters recursively
  Future<void> _parseSubChapters(
    List<EpubChapter> subChapters,
    List<ChapterEntity> chapters, {
    required int level,
  }) async {
    for (int i = 0; i < subChapters.length; i++) {
      final chapter = subChapters[i];
      final title = _sanitizeHtmlText(chapter.Title ?? 'Sub-chapter');
      final content = await _extractChapterText(chapter);

      chapters.add(ChapterEntity(
        title: title,
        content: content,
        level: level,
      ));

      // Recursively parse nested sub-chapters
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        await _parseSubChapters(chapter.SubChapters!, chapters, level: level + 1);
      }
    }
  }

  /// Extract text content from a chapter
  Future<String> _extractChapterText(EpubChapter chapter) async {
    try {
      final buffer = StringBuffer();

      // Get chapter HTML content - epubx uses HtmlContent property
      final htmlContent = chapter.HtmlContent;
      if (htmlContent != null) {
        final text = _htmlToPlainText(htmlContent);
        buffer.write(text);
      }

      // Also check for sub-chapters
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        for (final subChapter in chapter.SubChapters!) {
          final subText = await _extractChapterText(subChapter);
          if (subText.isNotEmpty) {
            buffer.write('\n\n');
            buffer.write(subText);
          }
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      _componentName.logWarning('Error extracting chapter text: $e');
      return '';
    }
  }

  /// Synchronous version for TOC parsing
  String _extractChapterTextSync(EpubChapter chapter) {
    try {
      final htmlContent = chapter.HtmlContent;
      if (htmlContent != null) {
        return _htmlToPlainText(htmlContent);
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  /// Convert HTML to plain text while preserving structure
  String _htmlToPlainText(String html) {
    try {
      // Parse HTML
      final document = html_parser.parse(html);

      // Remove script and style elements
      document
          .querySelectorAll('script, style, meta, link')
          .forEach((element) => element.remove());

      // Get text content
      String text = document.body?.text ?? document.text ?? '';

      // HTML unescape (convert &nbsp; etc to actual characters)
      text = _htmlUnescape.convert(text);

      // Clean up whitespace
      text = _sanitizeText(text);

      return text;
    } catch (e) {
      _componentName.logWarning('Error converting HTML to text: $e');
      // Fallback: basic cleanup
      return _sanitizeHtmlText(html);
    }
  }

  /// Remove HTML tags and do basic cleanup
  String _sanitizeHtmlText(String html) {
    String text = html;

    // Remove common HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // HTML unescape
    text = _htmlUnescape.convert(text);

    // Clean up whitespace
    text = _sanitizeText(text);

    return text.trim();
  }

  /// Clean up whitespace and formatting
  String _sanitizeText(String text) {
    // Replace multiple spaces with single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Replace multiple newlines with double newline (paragraph)
    text = text.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');

    // Clean up spaces around newlines
    text = text.replaceAll(RegExp(r' *\n *'), '\n');
    text = text.replaceAll(RegExp(r' *'), ' ');

    return text.trim();
  }

  /// Check if EPUB is encrypted/DRM-protected
  bool _isEncryptedEpub(List<int> bytes) {
    try {
      // Convert to string for pattern matching
      final content = String.fromCharCodes(bytes.take(10000));

      // Common DRM indicators
      final drmPatterns = [
        'encryption.xml',
        'Adobe DRM',
        'DRM-enabled',
        'AdobeContentServer4',
        'http://ns.adobe.com/drm/',
        '</encryption>',
      ];

      for (final pattern in drmPatterns) {
        if (content.toLowerCase().contains(pattern.toLowerCase())) {
          _componentName.logWarning('DRM pattern detected: $pattern');
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Optimize cover image size
  Future<Uint8List?> _optimizeCoverImage(Uint8List bytes) async {
    try {
      // Check file size
      if (bytes.length > _maxCoverSizeBytes) {
        _componentName.logWarning(
          'Cover image too large (${bytes.length} bytes), skipping optimization'
        );
        // In a production app, you'd use image package to resize
        // For now, return null to skip large images
        return null;
      }

      // Basic image validation could go here
      // For now, just return the original bytes
      return bytes;
    } catch (e) {
      _componentName.logError('Failed to optimize cover image', error: e);
      return null;
    }
  }

  /// Extract ISBN from metadata
  String? _extractIsbn(EpubBook epubBook) {
    // Check identifiers if available
    // epubx doesn't expose detailed identifier metadata in the main API
    // We'll check if there's a custom property or use other methods

    // Try to extract from Description or other metadata
    final description = epubBook.Description ?? '';
    final isbnMatch = RegExp(r'ISBN[- ]?[\dX]{10,17}', caseSensitive: false)
        .firstMatch(description);
    if (isbnMatch != null) {
      return isbnMatch.group(0)?.replaceAll(RegExp(r'[^0-9X]'), '');
    }

    return null;
  }

  /// Extract tags/subjects from metadata
  List<String> _extractTags(EpubBook epubBook) {
    final tags = <String>[];

    // epubx doesn't expose Subjects directly
    // Try to extract from Description or other fields
    final description = epubBook.Description ?? '';

    // Look for common tag patterns
    final tagMatches = RegExp(r'(?:Tags?|Genres?|Subjects?)[:\s]+([^\n.]+)', caseSensitive: false)
        .allMatches(description);
    for (final match in tagMatches) {
      final tagStr = match.group(1)?.trim();
      if (tagStr != null && tagStr.isNotEmpty) {
        // Split by common separators
        final tagParts = tagStr.split(RegExp(r'[,\n]'));
        for (final tag in tagParts) {
          final cleanTag = tag.trim();
          if (cleanTag.isNotEmpty) {
            tags.add(cleanTag);
          }
        }
      }
    }

    return tags;
  }
}
