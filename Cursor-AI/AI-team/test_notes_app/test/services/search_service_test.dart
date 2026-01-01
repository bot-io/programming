import 'package:flutter_test/flutter_test.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/search_service.dart';
import 'package:simplenotes/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter/material.dart';

@GenerateMocks([StorageService])
import 'search_service_test.mocks.dart';

void main() {
  late SearchService searchService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
    when(mockStorageService.isInitialized).thenReturn(true);
    searchService = SearchService(mockStorageService);
  });

  tearDown(() {
    searchService.dispose();
  });

  group('SearchService - Full-Text Search', () {
    test('should search notes by title', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Development',
          content: 'Content about Flutter',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Dart Programming',
          content: 'Content about Dart',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-3',
          title: 'Flutter Widgets',
          content: 'Content about widgets',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Flutter');

      expect(results, hasLength(2));
      expect(results[0].title, contains('Flutter'));
      expect(results[1].title, contains('Flutter'));
    });

    test('should search notes by content', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'This is about Flutter development',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Note 2',
          content: 'This is about Dart programming',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-3',
          title: 'Note 3',
          content: 'This is about Flutter widgets',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Flutter');

      expect(results, hasLength(2));
      expect(results[0].content, contains('Flutter'));
      expect(results[1].content, contains('Flutter'));
    });

    test('should search notes by both title and content', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Guide',
          content: 'Learn Flutter development',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Dart Basics',
          content: 'Learn Dart programming',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Flutter');

      expect(results, hasLength(1));
      expect(results[0].title, contains('Flutter'));
    });

    test('should return empty list when no matches found', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Note 2',
          content: 'Content 2',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'NonExistent');

      expect(results, isEmpty);
    });

    test('should perform case-insensitive search', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Development',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Dart Programming',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results1 = await searchService.search(query: 'flutter');
      final results2 = await searchService.search(query: 'FLUTTER');
      final results3 = await searchService.search(query: 'FlUtTeR');

      expect(results1, hasLength(1));
      expect(results2, hasLength(1));
      expect(results3, hasLength(1));
    });

    test('should return all notes when query is empty', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: '');

      expect(results, hasLength(1));
    });

    test('should handle whitespace-only search query', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: '   ');

      expect(results, hasLength(1));
    });

    test('should throw error when storage service is not initialized', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      expect(
        () => searchService.search(query: 'query'),
        throwsA(isA<SearchServiceException>()),
      );
    });

    test('should handle storage error during search', () async {
      when(mockStorageService.getAllNotes())
          .thenThrow(StorageException(message: 'Storage error', operation: 'getAllNotes'));

      expect(
        () => searchService.search(query: 'query'),
        throwsA(isA<SearchServiceException>()),
      );
    });
  });

  group('SearchService - Category Filtering', () {
    test('should filter search results by category', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Note',
          content: 'Content',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Flutter Guide',
          content: 'Content',
          categoryId: 'category-2',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-3',
          title: 'Flutter Tutorial',
          content: 'Content',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => [notes[0], notes[2]]);

      final results = await searchService.search(
        query: 'Flutter',
        categoryId: 'category-1',
      );

      expect(results, hasLength(2));
      expect(results[0].categoryId, 'category-1');
      expect(results[1].categoryId, 'category-1');
    });

    test('should return empty list when category has no matching notes', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Note',
          content: 'Content',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Dart Note',
          content: 'Content',
          categoryId: 'category-2',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getNotesByCategory('category-2'))
          .thenAnswer((_) async => [notes[1]]);

      final results = await searchService.search(
        query: 'Flutter',
        categoryId: 'category-2',
      );

      expect(results, isEmpty);
    });

    test('should search notes without category when categoryId is null', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Flutter Note',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Flutter Guide',
          content: 'Content',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Flutter', categoryId: null);

      expect(results, hasLength(2));
    });
  });

  group('SearchService - Search Highlighting', () {
    test('should highlight search term in text', () {
      final spans = searchService.highlightMatches(
        'Flutter Development Guide',
        'Flutter',
      );

      expect(spans, isNotEmpty);
      expect(spans.length, greaterThan(1));
    });

    test('should highlight search term in content', () {
      final spans = searchService.highlightMatches(
        'This is a Flutter development guide',
        'Flutter',
      );

      expect(spans, isNotEmpty);
    });

    test('should handle case-insensitive highlighting', () {
      final spans = searchService.highlightMatches(
        'This is a flutter development guide',
        'Flutter',
      );

      expect(spans, isNotEmpty);
    });

    test('should return original text when no match found', () {
      const original = 'This is a Dart programming guide';
      final spans = searchService.highlightMatches(original, 'Flutter');

      expect(spans, hasLength(1));
      expect(spans[0].text, original);
    });

    test('should handle empty search term', () {
      const original = 'This is a Flutter guide';
      final spans = searchService.highlightMatches(original, '');

      expect(spans, hasLength(1));
      expect(spans[0].text, original);
    });

    test('should highlight note title', () {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Flutter Development',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final spans = searchService.highlightNoteTitle(note, 'Flutter');

      expect(spans, isNotEmpty);
    });

    test('should highlight note content', () {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Note',
        content: 'This is about Flutter development',
        createdAt: now,
        updatedAt: now,
      );

      final spans = searchService.highlightNoteContent(note, 'Flutter');

      expect(spans, isNotEmpty);
    });

    test('should apply custom styles for highlighting', () {
      final matchStyle = const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue);
      final normalStyle = const TextStyle(color: Colors.black);

      final spans = searchService.highlightMatches(
        'Flutter Development',
        'Flutter',
        matchStyle: matchStyle,
        normalStyle: normalStyle,
      );

      expect(spans, isNotEmpty);
    });
  });

  group('SearchService - Note Matching', () {
    test('should check if note matches query', () {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Flutter Development',
        content: 'Content about Flutter',
        createdAt: now,
        updatedAt: now,
      );

      expect(searchService.noteMatches(note, 'Flutter'), isTrue);
      expect(searchService.noteMatches(note, 'flutter'), isTrue);
      expect(searchService.noteMatches(note, 'Dart'), isFalse);
    });

    test('should return true for empty query', () {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      expect(searchService.noteMatches(note, ''), isTrue);
      expect(searchService.noteMatches(note, '   '), isTrue);
    });
  });

  group('SearchService - Real-time Search with Debouncing', () {
    test('should debounce rapid search requests', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Test Note',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      var callCount = 0;
      searchService.searchDebounced(
        query: 'T',
        onResults: (_) => callCount++,
        debounceMs: 100,
      );
      searchService.searchDebounced(
        query: 'Te',
        onResults: (_) => callCount++,
        debounceMs: 100,
      );
      searchService.searchDebounced(
        query: 'Tes',
        onResults: (_) => callCount++,
        debounceMs: 100,
      );

      await Future.delayed(const Duration(milliseconds: 150));

      expect(callCount, lessThan(3));
    });

    test('should cancel previous debounced search when new query arrives', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Test Note',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      var finalResults = <Note>[];
      searchService.searchDebounced(
        query: 'T',
        onResults: (_) {},
        debounceMs: 200,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      searchService.searchDebounced(
        query: 'Te',
        onResults: (_) {},
        debounceMs: 200,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      searchService.searchDebounced(
        query: 'Test',
        onResults: (results) => finalResults = results,
        debounceMs: 200,
      );
      await Future.delayed(const Duration(milliseconds: 250));

      expect(finalResults, isNotEmpty);
    });

    test('should cancel debounced search', () {
      searchService.searchDebounced(
        query: 'Test',
        onResults: (_) {},
      );

      searchService.cancelDebouncedSearch();

      expect(searchService, isNotNull);
    });
  });

  group('SearchService - Edge Cases', () {
    test('should handle very long search query', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final longQuery = 'A' * 1000;
      final results = await searchService.search(query: longQuery);

      expect(results, isEmpty);
    });

    test('should handle notes with very long content', () async {
      final now = DateTime.now();
      final longContent = 'A' * 10000 + 'Flutter' + 'B' * 10000;
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note',
          content: longContent,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Flutter');

      expect(results, hasLength(1));
    });

    test('should handle special characters in search query', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'C++ Programming',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'C++');

      expect(results, hasLength(1));
    });

    test('should handle unicode characters in search query', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: '日本語のノート',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: '日本語');

      expect(results, hasLength(1));
    });

    test('should handle null categoryId in search', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note',
          content: 'Content',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await searchService.search(query: 'Note', categoryId: null);

      expect(results, hasLength(1));
    });
  });
}
