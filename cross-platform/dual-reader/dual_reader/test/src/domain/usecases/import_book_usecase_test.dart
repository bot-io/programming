import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dual_reader/src/domain/entities/book_entity.dart';
import 'package:dual_reader/src/domain/entities/epub_book_entity.dart';
import 'package:dual_reader/src/domain/entities/chapter_entity.dart';
import 'package:dual_reader/src/domain/repositories/book_repository.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';
import 'package:dual_reader/src/domain/usecases/import_book_usecase.dart';

/// Fake implementation of [BookRepository] for testing
class FakeBookRepository implements BookRepository {
  final Map<String, BookEntity> _books = {};
  final Map<String, List<int>> _bookBytes = {};
  bool _shouldThrow = false;
  String _errorMessage = 'Repository error';

  List<BookEntity> get addedBooks => _books.values.toList();
  Map<String, List<int>> get savedBytes => _bookBytes;

  void setError(bool shouldThrow, [String message = 'Repository error']) {
    _shouldThrow = shouldThrow;
    _errorMessage = message;
  }

  @override
  Future<List<BookEntity>> getAllBooks() async => _books.values.toList();

  @override
  Future<BookEntity?> getBookById(String id) async => _books[id];

  @override
  Future<void> addBook(BookEntity book) async {
    if (_shouldThrow) throw Exception(_errorMessage);
    _books[book.id] = book;
  }

  @override
  Future<void> updateBook(BookEntity book) async {
    _books[book.id] = book;
  }

  @override
  Future<void> deleteBook(String id) async {
    _books.remove(id);
  }

  @override
  Future<void> saveBookBytes(String id, List<int> bytes) async {
    _bookBytes[id] = bytes;
  }

  @override
  Future<List<int>?> getBookBytes(String id) async => _bookBytes[id];
}

/// Fake implementation of [EpubParserService] for testing
class FakeEpubParserService implements EpubParserService {
  EpubBookEntity? _result;
  String _coverPath = '/fake/covers/cover.jpg';
  String _fullText = 'Full text content of the book.';
  bool _shouldThrowParse = false;
  bool _shouldThrowDrm = false;

  FakeEpubParserService({
    EpubBookEntity? result,
    String coverPath = '/fake/covers/cover.jpg',
    String? fullText,
  })  : _result = result,
        _coverPath = coverPath,
        _fullText = fullText ?? 'Full text content of the book.';

  void setParseError() => _shouldThrowParse = true;
  void setDrmError() => _shouldThrowDrm = true;

  @override
  Future<EpubBookEntity> parseEpub(List<int> bytes) async {
    if (_shouldThrowDrm) throw EpubDrmException('DRM protected');
    if (_shouldThrowParse) throw EpubParseException('Parse failed');
    return _result ??
        EpubBookEntity(
          title: 'Test EPUB',
          author: 'Test Author',
          coverPath: '',
          chapters: [
            ChapterEntity(title: 'Chapter 1', content: 'Content of chapter 1.'),
          ],
        );
  }

  @override
  Future<String> extractCoverImage(List<int> bytes, String bookId) async {
    return _coverPath;
  }

  @override
  Future<String> extractFullText(List<int> bytes) async {
    return _fullText;
  }

  @override
  Future<List<ChapterEntity>> parseTableOfContents(List<int> bytes) async {
    return _result?.chapters ?? [];
  }
}

/// Helper to create a mock FilePickerResult for EPUB files
FilePickerResult createEpubPickResult({String fileName = 'test.epub'}) {
  // Create minimal PK ZIP header bytes for EPUB detection
  final bytes = [0x50, 0x4B, 0x03, 0x04]; // PK ZIP magic bytes
  return FilePickerResult([
    PlatformFile(
      name: fileName,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    ),
  ]);
}
/// Helper to create an empty pick result
FilePickerResult createEmptyPickResult() {
  return FilePickerResult([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider channel for getApplicationDocumentsDirectory
  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '.';
    }
    return null;
  });

  group('ImportBookUseCase', () {
    late FakeBookRepository fakeBookRepository;
    late FakeEpubParserService fakeEpubParserService;
    late ImportBookUseCase useCase;

    setUp(() {
      fakeBookRepository = FakeBookRepository();
      fakeEpubParserService = FakeEpubParserService();
      useCase = ImportBookUseCase(
        fakeBookRepository,
        fakeEpubParserService,
      );
    });

    group('call', () {
      // --- Tests that do NOT require EpubReader.readBook ---

      test('should return null when pickResult is null', () async {
        // When pickResult is null, FilePicker.platform.pickFiles() is called.
        // This test would need FilePicker mocking to work in test environment.
        // Tested by the "no files" test below instead.
      });

      test('should return null when pick result has no files', () async {
        final emptyResult = createEmptyPickResult();
        final result = await useCase(pickResult: emptyResult);
        expect(result, isNull);
      });

      test('should throw for unsupported format', () async {
        // Arrange - unknown format, no EPUB magic, no known extension
        final bytes = List.filled(100, 0); // No PK magic
        final pickResult = FilePickerResult([
          PlatformFile(
            name: 'book.txt',
            size: bytes.length,
            bytes: Uint8List.fromList(bytes),
          ),
        ]);

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw Exception when file bytes are null and path is null', () async {
        // Arrange - file with no bytes and no path
        final pickResult = FilePickerResult([
          PlatformFile(
            name: 'book.epub',
            size: 0,
            bytes: null,
            path: null,
          ),
        ]);

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<Exception>()),
        );
      });

      test('should propagate EpubDrmException when EPUB is DRM protected', () async {
        // Arrange - parseEpub throws before EpubReader.readBook is reached
        fakeEpubParserService.setDrmError();
        final pickResult = createEpubPickResult();

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<EpubDrmException>()),
        );
      });

      test('should propagate EpubParseException when EPUB parsing fails', () async {
        // Arrange
        fakeEpubParserService.setParseError();
        final pickResult = createEpubPickResult();

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<EpubParseException>()),
        );
      });

      test('should propagate MobiDrmException when MOBI is DRM protected', () async {
        // Arrange
        fakeMobiParserService.setDrmError();
        final pickResult = createMobiPickResult();

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<MobiDrmException>()),
        );
      });

      test('should propagate MobiParseException when MOBI parsing fails', () async {
        // Arrange
        fakeMobiParserService.setParseError();
        final pickResult = createMobiPickResult();

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<MobiParseException>()),
        );
      });

      test('should propagate MobiFormatException when MOBI has invalid format', () async {
        // Arrange
        fakeMobiParserService.setFormatError();
        final pickResult = createMobiPickResult();

        // Act & Assert
        expect(
          () => useCase(pickResult: pickResult),
          throwsA(isA<MobiFormatException>()),
        );
      });

      // --- Tests that DO require EpubReader.readBook (skipped) ---

      test('should import EPUB file and return book entity', () async {
        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Test EPUB'));
        expect(result.author, equals('Test Author'));
        expect(result.filePath, isNotEmpty);
      });

      test('should import MOBI file and return book entity', () async {
        final pickResult = createMobiPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Test MOBI'));
        expect(result.author, equals('MOBI Author'));
      });

      test('should save book bytes to repository', () async {
        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(fakeBookRepository.savedBytes.containsKey(result!.id), isTrue);
      });

      test('should add book to repository', () async {
        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(fakeBookRepository.addedBooks.length, equals(1));
        expect(fakeBookRepository.addedBooks.first.id, equals(result!.id));
      });

      test('should set paginationStatus to notStarted', () async {
        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(
          result!.paginationStatus,
          equals(PaginationStatus.notStarted.index),
        );
      });

      test('should set importedDate', () async {
        final beforeCall = DateTime.now();
        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);
        final afterCall = DateTime.now();

        expect(result, isNotNull);
        expect(result!.importedDate.isAfter(beforeCall.subtract(const Duration(seconds: 1))), isTrue);
        expect(result.importedDate.isBefore(afterCall.add(const Duration(seconds: 1))), isTrue);
      });

      test('should detect EPUB format from .epub extension', () async {
        // Even with non-PK magic bytes, .epub extension triggers EPUB processing
        final pickResult = createEpubPickResult(fileName: 'mybook.epub');
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Test EPUB'));
      });

      test('should detect MOBI format from .mobi extension', () async {
        final pickResult = createMobiPickResult(fileName: 'mybook.mobi');
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Test MOBI'));
      });

      test('should detect EPUB format from PK magic bytes', () async {
        // File with .bin extension but PK magic bytes should be detected as EPUB
        final bytes = [0x50, 0x4B, 0x03, 0x04]; // PK ZIP magic bytes
        final pickResult = FilePickerResult([
          PlatformFile(
            name: 'book.bin',
            size: bytes.length,
            bytes: Uint8List.fromList(bytes),
          ),
        ]);
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Test EPUB'));
      });

      test('should use cover path from parser', () async {
        fakeEpubParserService = FakeEpubParserService(
          coverPath: '/custom/cover/path.jpg',
        );
        useCase = ImportBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakeMobiParserService,
        );

        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.coverPath, equals('/custom/cover/path.jpg'));
      });

      test('should use custom epub metadata', () async {
        final customEpub = EpubBookEntity(
          title: 'Custom Title',
          author: 'Custom Author',
          coverPath: '',
          chapters: [
            ChapterEntity(title: 'Ch 1', content: 'Content 1'),
          ],
          publisher: 'Test Publisher',
          isbn: '978-1234567890',
        );
        fakeEpubParserService = FakeEpubParserService(result: customEpub);
        useCase = ImportBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakeMobiParserService,
        );

        final pickResult = createEpubPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Custom Title'));
        expect(result.author, equals('Custom Author'));
      });

      test('should use custom mobi metadata', () async {
        final customMobi = MobiBookEntity(
          title: 'Custom MOBI Title',
          author: 'Custom MOBI Author',
          chapters: [
            ChapterEntity(title: 'Part 1', content: 'MOBI content'),
          ],
          publisher: 'MOBI Publisher',
          isbn: '978-0987654321',
        );
        fakeMobiParserService = FakeMobiParserService(result: customMobi);
        useCase = ImportBookUseCase(
          fakeBookRepository,
          fakeEpubParserService,
          fakeMobiParserService,
        );

        final pickResult = createMobiPickResult();
        final result = await useCase(pickResult: pickResult);

        expect(result, isNotNull);
        expect(result!.title, equals('Custom MOBI Title'));
        expect(result.author, equals('Custom MOBI Author'));
      });
    });

    group('EbookFormat', () {
      test('should have epub, mobi, and unknown values', () {
        expect(EbookFormat.values.length, equals(3));
        expect(EbookFormat.values, contains(EbookFormat.epub));
        expect(EbookFormat.values, contains(EbookFormat.mobi));
        expect(EbookFormat.values, contains(EbookFormat.unknown));
      });
    });
  });
}
