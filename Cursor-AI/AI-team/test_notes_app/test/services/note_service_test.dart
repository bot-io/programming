import 'package:flutter_test/flutter_test.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/services/note_service.dart';
import 'package:simplenotes/services/storage_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([StorageService])
import 'note_service_test.mocks.dart';

void main() {
  late NoteService noteService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
    when(mockStorageService.isInitialized).thenReturn(true);
    noteService = NoteService(mockStorageService);
  });

  group('NoteService - Create Operations', () {
    test('should create a note successfully', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_1234567890_123456',
        title: 'Test Note',
        content: 'Test content',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.createNote(any)).thenAnswer((_) async => note);

      final result = await noteService.createNote(
        title: 'Test Note',
        content: 'Test content',
      );

      expect(result, isNotNull);
      expect(result.title, 'Test Note');
      expect(result.content, 'Test content');
      verify(mockStorageService.createNote(any)).called(1);
    });

    test('should create a note with category', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_1234567890_123456',
        title: 'Categorized Note',
        content: 'Content',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.createNote(any)).thenAnswer((_) async => note);

      final result = await noteService.createNote(
        title: 'Categorized Note',
        content: 'Content',
        categoryId: 'category-1',
      );

      expect(result.categoryId, 'category-1');
      verify(mockStorageService.createNote(any)).called(1);
    });

    test('should trim title when creating note', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note_1234567890_123456',
        title: 'Trimmed Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.createNote(any)).thenAnswer((_) async => note);

      final result = await noteService.createNote(
        title: '  Trimmed Note  ',
        content: 'Content',
      );

      expect(result.title, 'Trimmed Note');
      verify(mockStorageService.createNote(any)).called(1);
    });

    test('should throw error when creating note with empty title', () async {
      expect(
        () => noteService.createNote(title: '', content: 'Content'),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.createNote(any));
    });

    test('should throw error when creating note with whitespace-only title', () async {
      expect(
        () => noteService.createNote(title: '   ', content: 'Content'),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.createNote(any));
    });

    test('should throw error when storage service is not initialized', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      expect(
        () => noteService.createNote(title: 'Test Note', content: 'Content'),
        throwsA(isA<NoteServiceException>()),
      );
    });

    test('should handle storage error during note creation', () async {
      when(mockStorageService.createNote(any))
          .thenThrow(StorageException(message: 'Storage error', operation: 'createNote'));

      expect(
        () => noteService.createNote(title: 'Test Note', content: 'Content'),
        throwsA(isA<NoteServiceException>()),
      );
    });
  });

  group('NoteService - Read Operations', () {
    test('should get a note by id', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Test Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.getNote('note-1')).thenAnswer((_) async => note);

      final result = await noteService.getNote('note-1');

      expect(result, isNotNull);
      expect(result!.id, 'note-1');
      expect(result.title, 'Test Note');
      verify(mockStorageService.getNote('note-1')).called(1);
    });

    test('should return null when note does not exist', () async {
      when(mockStorageService.getNote('non-existent')).thenAnswer((_) async => null);

      final result = await noteService.getNote('non-existent');

      expect(result, isNull);
      verify(mockStorageService.getNote('non-existent')).called(1);
    });

    test('should throw error when note id is empty', () async {
      expect(
        () => noteService.getNote(''),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.getNote(any));
    });

    test('should throw error when storage service is not initialized', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      expect(
        () => noteService.getNote('note-1'),
        throwsA(isA<NoteServiceException>()),
      );
    });

    test('should handle storage error during note retrieval', () async {
      when(mockStorageService.getNote('note-1'))
          .thenThrow(StorageException(message: 'Storage error', operation: 'getNote'));

      expect(
        () => noteService.getNote('note-1'),
        throwsA(isA<NoteServiceException>()),
      );
    });

    test('should get all notes', () async {
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

      final result = await noteService.getNotes();

      expect(result, hasLength(2));
      expect(result[0].title, 'Note 1');
      expect(result[1].title, 'Note 2');
      verify(mockStorageService.getAllNotes()).called(1);
    });

    test('should return empty list when no notes exist', () async {
      when(mockStorageService.getAllNotes()).thenAnswer((_) async => []);

      final result = await noteService.getNotes();

      expect(result, isEmpty);
      verify(mockStorageService.getAllNotes()).called(1);
    });

    test('should get notes filtered by category', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          categoryId: 'category-1',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => notes);

      final result = await noteService.getNotes(categoryId: 'category-1');

      expect(result, hasLength(1));
      expect(result[0].categoryId, 'category-1');
      verify(mockStorageService.getNotesByCategory('category-1')).called(1);
    });
  });

  group('NoteService - Update Operations', () {
    test('should update a note successfully', () async {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final originalNote = Note(
        id: 'note-1',
        title: 'Original Title',
        content: 'Original Content',
        createdAt: now,
        updatedAt: now,
      );
      final updatedNote = Note(
        id: 'note-1',
        title: 'Updated Title',
        content: 'Updated Content',
        createdAt: now,
        updatedAt: later,
      );

      when(mockStorageService.getNote('note-1'))
          .thenAnswer((_) async => originalNote);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => updatedNote);

      final result = await noteService.updateNote(
        id: 'note-1',
        title: 'Updated Title',
        content: 'Updated Content',
      );

      expect(result.title, 'Updated Title');
      expect(result.content, 'Updated Content');
      expect(result.updatedAt.isAfter(originalNote.updatedAt), isTrue);
      verify(mockStorageService.updateNote(any)).called(1);
    });

    test('should update only title when content is not provided', () async {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final originalNote = Note(
        id: 'note-1',
        title: 'Original Title',
        content: 'Original Content',
        createdAt: now,
        updatedAt: now,
      );
      final updatedNote = Note(
        id: 'note-1',
        title: 'Updated Title',
        content: 'Original Content',
        createdAt: now,
        updatedAt: later,
      );

      when(mockStorageService.getNote('note-1'))
          .thenAnswer((_) async => originalNote);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => updatedNote);

      final result = await noteService.updateNote(
        id: 'note-1',
        title: 'Updated Title',
      );

      expect(result.title, 'Updated Title');
      expect(result.content, 'Original Content');
      verify(mockStorageService.updateNote(any)).called(1);
    });

    test('should update categoryId', () async {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final originalNote = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      final updatedNote = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: later,
      );

      when(mockStorageService.getNote('note-1'))
          .thenAnswer((_) async => originalNote);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => updatedNote);

      final result = await noteService.updateNote(
        id: 'note-1',
        categoryId: 'category-1',
      );

      expect(result.categoryId, 'category-1');
      verify(mockStorageService.updateNote(any)).called(1);
    });

    test('should remove categoryId when empty string is provided', () async {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final originalNote = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        categoryId: 'category-1',
        createdAt: now,
        updatedAt: now,
      );
      final updatedNote = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        categoryId: null,
        createdAt: now,
        updatedAt: later,
      );

      when(mockStorageService.getNote('note-1'))
          .thenAnswer((_) async => originalNote);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => updatedNote);

      final result = await noteService.updateNote(
        id: 'note-1',
        categoryId: '',
      );

      expect(result.categoryId, isNull);
      verify(mockStorageService.updateNote(any)).called(1);
    });

    test('should trim title when updating note', () async {
      final now = DateTime.now();
      final later = now.add(const Duration(hours: 1));
      final originalNote = Note(
        id: 'note-1',
        title: 'Original Title',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );
      final updatedNote = Note(
        id: 'note-1',
        title: 'Trimmed Title',
        content: 'Content',
        createdAt: now,
        updatedAt: later,
      );

      when(mockStorageService.getNote('note-1'))
          .thenAnswer((_) async => originalNote);
      when(mockStorageService.updateNote(any))
          .thenAnswer((_) async => updatedNote);

      final result = await noteService.updateNote(
        id: 'note-1',
        title: '  Trimmed Title  ',
      );

      expect(result.title, 'Trimmed Title');
      verify(mockStorageService.updateNote(any)).called(1);
    });

    test('should throw error when updating non-existent note', () async {
      when(mockStorageService.getNote('non-existent'))
          .thenAnswer((_) async => null);

      expect(
        () => noteService.updateNote(id: 'non-existent', title: 'New Title'),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.updateNote(any));
    });

    test('should throw error when updating with empty title', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.getNote('note-1')).thenAnswer((_) async => note);

      expect(
        () => noteService.updateNote(id: 'note-1', title: ''),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.updateNote(any));
    });

    test('should throw error when storage service is not initialized', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      expect(
        () => noteService.updateNote(id: 'note-1', title: 'New Title'),
        throwsA(isA<NoteServiceException>()),
      );
    });

    test('should handle storage error during note update', () async {
      final now = DateTime.now();
      final note = Note(
        id: 'note-1',
        title: 'Note',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      when(mockStorageService.getNote('note-1')).thenAnswer((_) async => note);
      when(mockStorageService.updateNote(any))
          .thenThrow(StorageException(message: 'Storage error', operation: 'updateNote'));

      expect(
        () => noteService.updateNote(id: 'note-1', title: 'New Title'),
        throwsA(isA<NoteServiceException>()),
      );
    });
  });

  group('NoteService - Delete Operations', () {
    test('should delete a note successfully', () async {
      when(mockStorageService.deleteNote('note-1')).thenAnswer((_) async => true);

      final result = await noteService.deleteNote('note-1');

      expect(result, isTrue);
      verify(mockStorageService.deleteNote('note-1')).called(1);
    });

    test('should return false when note does not exist', () async {
      when(mockStorageService.deleteNote('non-existent')).thenAnswer((_) async => false);

      final result = await noteService.deleteNote('non-existent');

      expect(result, isFalse);
      verify(mockStorageService.deleteNote('non-existent')).called(1);
    });

    test('should throw error when note id is empty', () async {
      expect(
        () => noteService.deleteNote(''),
        throwsA(isA<NoteServiceException>()),
      );
      verifyNever(mockStorageService.deleteNote(any));
    });

    test('should throw error when storage service is not initialized', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      expect(
        () => noteService.deleteNote('note-1'),
        throwsA(isA<NoteServiceException>()),
      );
    });

    test('should handle storage error during note deletion', () async {
      when(mockStorageService.deleteNote('note-1'))
          .thenThrow(StorageException(message: 'Storage error', operation: 'deleteNote'));

      expect(
        () => noteService.deleteNote('note-1'),
        throwsA(isA<NoteServiceException>()),
      );
    });
  });

  group('NoteService - Search Operations', () {
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

      final results = await noteService.searchNotes(query: 'Flutter');

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
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results = await noteService.searchNotes(query: 'Flutter');

      expect(results, hasLength(1));
      expect(results[0].content, contains('Flutter'));
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
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final results1 = await noteService.searchNotes(query: 'flutter');
      final results2 = await noteService.searchNotes(query: 'FLUTTER');
      final results3 = await noteService.searchNotes(query: 'FlUtTeR');

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

      final results = await noteService.searchNotes(query: '');

      expect(results, hasLength(1));
    });

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
      ];

      when(mockStorageService.getNotesByCategory('category-1'))
          .thenAnswer((_) async => [notes[0]]);

      final results = await noteService.searchNotes(
        query: 'Flutter',
        categoryId: 'category-1',
      );

      expect(results, hasLength(1));
      expect(results[0].categoryId, 'category-1');
    });

    test('should handle storage error during search', () async {
      when(mockStorageService.getAllNotes())
          .thenThrow(StorageException(message: 'Storage error', operation: 'getAllNotes'));

      expect(
        () => noteService.searchNotes(query: 'query'),
        throwsA(isA<NoteServiceException>()),
      );
    });
  });

  group('NoteService - Sorting Operations', () {
    test('should sort notes by createdAt descending', () async {
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
          createdAt: now.add(const Duration(hours: 1)),
          updatedAt: now.add(const Duration(hours: 1)),
        ),
        Note(
          id: 'note-3',
          title: 'Note 3',
          content: 'Content 3',
          createdAt: now.add(const Duration(hours: 2)),
          updatedAt: now.add(const Duration(hours: 2)),
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final result = await noteService.getNotes(
        sortBy: NoteSortField.createdAt,
        sortOrder: SortOrder.descending,
      );

      expect(result, hasLength(3));
      expect(result[0].id, 'note-3');
      expect(result[1].id, 'note-2');
      expect(result[2].id, 'note-1');
    });

    test('should sort notes by updatedAt ascending', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Note 1',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 2)),
        ),
        Note(
          id: 'note-2',
          title: 'Note 2',
          content: 'Content 2',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-3',
          title: 'Note 3',
          content: 'Content 3',
          createdAt: now,
          updatedAt: now.add(const Duration(hours: 1)),
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final result = await noteService.getNotes(
        sortBy: NoteSortField.updatedAt,
        sortOrder: SortOrder.ascending,
      );

      expect(result, hasLength(3));
      expect(result[0].id, 'note-2');
      expect(result[1].id, 'note-3');
      expect(result[2].id, 'note-1');
    });

    test('should sort notes by title alphabetically', () async {
      final now = DateTime.now();
      final notes = [
        Note(
          id: 'note-1',
          title: 'Zebra Note',
          content: 'Content 1',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-2',
          title: 'Apple Note',
          content: 'Content 2',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 'note-3',
          title: 'Banana Note',
          content: 'Content 3',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final result = await noteService.getNotes(
        sortBy: NoteSortField.title,
        sortOrder: SortOrder.ascending,
      );

      expect(result, hasLength(3));
      expect(result[0].id, 'note-2');
      expect(result[1].id, 'note-3');
      expect(result[2].id, 'note-1');
    });

    test('should use default sort (updatedAt descending)', () async {
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
          updatedAt: now.add(const Duration(hours: 1)),
        ),
      ];

      when(mockStorageService.getAllNotes()).thenAnswer((_) async => notes);

      final result = await noteService.getNotes();

      expect(result, hasLength(2));
      expect(result[0].id, 'note-2');
    });
  });

  group('NoteService - Error Handling', () {
    test('should throw NoteServiceException with proper message', () async {
      when(mockStorageService.isInitialized).thenReturn(false);

      try {
        await noteService.getNote('note-1');
        fail('Should have thrown NoteServiceException');
      } catch (e) {
        expect(e, isA<NoteServiceException>());
        expect(e.toString(), contains('Storage service is not initialized'));
        expect(e.toString(), contains('getNote'));
      }
    });

    test('should preserve original error in exception', () async {
      final originalError = StorageException(
        message: 'Original error',
        operation: 'getNote',
      );

      when(mockStorageService.getNote('note-1'))
          .thenThrow(originalError);

      try {
        await noteService.getNote('note-1');
        fail('Should have thrown NoteServiceException');
      } catch (e) {
        expect(e, isA<NoteServiceException>());
        expect(e.originalError, originalError);
      }
    });
  });

  group('NoteService - Constructor', () {
    test('should throw ArgumentError when storage service is null', () {
      expect(
        () => NoteService(null as dynamic),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
