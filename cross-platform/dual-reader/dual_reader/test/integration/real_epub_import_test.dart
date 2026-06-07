import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/data/services/epub_parser_service_impl.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real EPUB Import Test', () {
    late EpubParserServiceImpl parser;

    setUp(() {
      parser = EpubParserServiceImpl();
    });

    test('parse a real EPUB file (Pride and Prejudice)', () async {
      // Try to read from the device/emulator location first, fallback to local
      final paths = [
        '/sdcard/Download/pride_and_prejudice.epub', // Android emulator
        'test/fixtures/pride_and_prejudice.epub', // Local test fixture
      ];

      List<int>? bytes;
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          print('Found EPUB at: $path (${bytes.length} bytes)');
          break;
        }
      }

      if (bytes == null) {
        print('SKIPPED: No EPUB file found at any expected location');
        return;
      }

      // Parse the EPUB
      print('Parsing EPUB...');
      final epubBook = await parser.parseEpub(bytes);

      // Verify basic metadata
      print('Title: ${epubBook.title}');
      print('Author: ${epubBook.author}');
      print('Chapters: ${epubBook.chapters.length}');
      print('Publisher: ${epubBook.publisher}');
      print('ISBN: ${epubBook.isbn}');

      expect(epubBook, isNotNull);
      expect(epubBook.title, isNotEmpty);
      expect(epubBook.chapters, isNotEmpty);

      // Print first 3 chapters
      for (int i = 0; i < epubBook.chapters.length && i < 3; i++) {
        final ch = epubBook.chapters[i];
        print('\n--- Chapter ${i + 1}: ${ch.title} ---');
        print(ch.content.substring(0, ch.content.length > 200 ? 200 : ch.content.length));
      }

      // Extract full text
      print('\nExtracting full text...');
      final fullText = await parser.extractFullText(bytes);
      print('Full text length: ${fullText.length} characters');
      expect(fullText, isNotEmpty);
      print('First 300 chars: ${fullText.substring(0, fullText.length > 300 ? 300 : fullText.length)}');

      // Extract cover image
      print('\nExtracting cover image...');
      final coverPath = await parser.extractCoverImage(bytes, 'test-book-id');
      print('Cover path: $coverPath');

      // Parse table of contents
      print('\nParsing table of contents...');
      final toc = await parser.parseTableOfContents(bytes);
      print('TOC entries: ${toc.length}');
      for (int i = 0; i < toc.length && i < 10; i++) {
        print('  ${i + 1}. ${toc[i].title}');
      }

      print('\n✅ REAL EPUB IMPORT TEST PASSED');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
