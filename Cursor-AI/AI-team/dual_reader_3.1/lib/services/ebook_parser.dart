import 'dart:io';
import 'dart:typed_data';
import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import '../models/book.dart';
import '../models/chapter.dart';
import 'storage_service.dart';
import 'mobi_parser.dart';

class EbookParser {
  final StorageService _storageService;
  late final MobiParser _mobiParser;

  EbookParser(this._storageService) {
    _mobiParser = MobiParser(_storageService);
  }

  Future<Book> parseBook(String filePath, Uint8List? fileData) async {
    // Handle both full paths and just filenames (for web)
    final fileName = filePath.contains('/') 
        ? filePath.split('/').last.toLowerCase()
        : filePath.toLowerCase();
    
    if (fileName.endsWith('.epub')) {
      return await _parseEpub(filePath, fileData);
    } else if (fileName.endsWith('.mobi')) {
      return await _mobiParser.parseMobi(filePath, fileData);
    } else {
      throw UnsupportedError('Unsupported file format. Please use EPUB or MOBI files.');
    }
  }

  Future<Book> _parseEpub(String filePath, Uint8List? fileData) async {
    try {
      EpubBook epubBook;
      
      if (kIsWeb && fileData != null) {
        // On web, use file data directly
        epubBook = EpubReader.readBook(fileData);
      } else {
        // On mobile/desktop, read from file path
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        epubBook = EpubReader.readBook(bytes);
      }

      // Extract metadata
      final title = epubBook.Title ?? 'Untitled';
      final author = epubBook.Author ?? 'Unknown Author';
      final language = epubBook.Language;

      // Extract cover image
      String? coverImagePath;
      if (epubBook.CoverImage != null && epubBook.CoverImage!.isNotEmpty) {
        try {
          final coverData = epubBook.CoverImage;
          if (coverData != null) {
            final bookId = _generateBookId(title, author);
            coverImagePath = await _storageService.saveCoverImage(
              bookId,
              coverData,
            );
          }
        } catch (e) {
          print('Error saving cover image: $e');
        }
      }

      // Generate bookId early for chapter references
      final bookId = _generateBookId(title, author);

      // Extract chapters and content
      final chapters = <Chapter>[];
      final fullTextBuffer = StringBuffer();
      final chapterHtmlMap = <String, String>{};
      int currentIndex = 0;

      if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
        for (int i = 0; i < epubBook.Chapters!.length; i++) {
          final epubChapter = epubBook.Chapters![i];
          final chapterTitle = epubChapter.Title ?? 'Chapter ${i + 1}';
          final chapterId = 'chapter_$i';
          final htmlContent = epubChapter.HtmlContent ?? '';
          final chapterContent = _extractTextFromHtml(htmlContent);
          
          final startIndex = currentIndex;
          final endIndex = currentIndex + chapterContent.length;

          chapters.add(Chapter(
            id: chapterId,
            title: chapterTitle,
            startIndex: startIndex,
            endIndex: endIndex,
            href: htmlContent,
            startPage: 0, // Will be calculated during pagination
            endPage: 0, // Will be calculated during pagination
            bookId: bookId,
          ));

          // Store HTML content for rich text rendering
          if (htmlContent.isNotEmpty) {
            chapterHtmlMap[chapterId] = htmlContent;
          }

          if (fullTextBuffer.isNotEmpty) {
            fullTextBuffer.write('\n\n');
          }
          fullTextBuffer.write(chapterContent);
          currentIndex = endIndex + 2; // +2 for \n\n
        }
      } else {
        // If no chapters, treat entire book as one chapter
        final contentMap = epubBook.Content ?? {};
        final contentList = contentMap.values.toList();
        
        if (contentList.isNotEmpty) {
          final htmlContents = contentList.map((c) => c.HtmlContent ?? '').toList();
          final htmlContent = htmlContents.join('\n\n');
          final content = _extractTextFromHtml(htmlContent);
          
          chapters.add(Chapter(
            id: 'chapter_0',
            title: 'Content',
            startIndex: 0,
            endIndex: content.length,
            href: htmlContent,
            startPage: 0, // Will be calculated during pagination
            endPage: 0, // Will be calculated during pagination
            bookId: bookId,
          ));
          
          if (htmlContent.isNotEmpty) {
            chapterHtmlMap['chapter_0'] = htmlContent;
          }
          
          fullTextBuffer.write(content);
        }
      }

      final fullText = fullTextBuffer.toString();

      return Book(
        id: bookId,
        title: title,
        author: author,
        filePath: filePath,
        format: 'epub',
        coverImagePath: coverImagePath,
        chapters: chapters,
        fullText: fullText,
        addedAt: DateTime.now(),
        language: language,
        chapterHtml: chapterHtmlMap.isNotEmpty ? chapterHtmlMap : null,
      );
    } catch (e) {
      throw Exception('Failed to parse EPUB file: $e');
    }
  }

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

  String _generateBookId(String title, String author) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${title}_${author}_$timestamp'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
