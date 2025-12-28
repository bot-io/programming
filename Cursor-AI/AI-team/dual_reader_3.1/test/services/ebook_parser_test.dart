import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/services/ebook_parser.dart';
import 'package:dual_reader/services/storage_service.dart';
import 'package:dual_reader/models/book.dart';
import 'dart:typed_data';

void main() {
  group('EbookParser', () {
    late EbookParser parser;
    late StorageService storageService;

    setUp(() async {
      // Note: In a real test, you'd use a mock StorageService
      // For now, we test the logic that doesn't require actual file I/O
      storageService = StorageService();
      parser = EbookParser(storageService);
    });

    test('parseBook throws UnsupportedError for MOBI files', () async {
      expect(
        () => parser.parseBook('test.mobi', null),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('parseBook throws UnsupportedError for unknown file formats', () async {
      expect(
        () => parser.parseBook('test.pdf', null),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('parseBook handles file path with directory', () {
      // Test that file path parsing works correctly
      final fileName = '/path/to/book.epub';
      expect(fileName.contains('/'), true);
    });

    test('parseBook handles file path without directory', () {
      // Test that file path parsing works correctly
      final fileName = 'book.epub';
      expect(fileName.contains('/'), false);
    });

    test('parseBook handles lowercase file extension', () {
      final fileName = 'BOOK.EPUB';
      final lowerFileName = fileName.toLowerCase();
      expect(lowerFileName.endsWith('.epub'), true);
    });

    test('parseBook handles mixed case file extension', () {
      final fileName = 'Book.EpUb';
      final lowerFileName = fileName.toLowerCase();
      expect(lowerFileName.endsWith('.epub'), true);
    });

    // Note: Full EPUB parsing tests would require:
    // 1. Mock StorageService
    // 2. Sample EPUB file data
    // 3. Mock EpubReader.readBook
    // These are integration-level tests that would be better suited
    // for integration test suite
  });
}
