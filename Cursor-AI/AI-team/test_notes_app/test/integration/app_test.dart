import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:simplenotes/models/note.dart';
import 'package:simplenotes/models/category.dart';
import 'package:simplenotes/providers/note_provider.dart';
import 'package:simplenotes/providers/category_provider.dart';
import 'package:simplenotes/providers/search_provider.dart';
import 'package:simplenotes/providers/theme_provider.dart';
import 'package:simplenotes/services/hive_storage_service.dart';
import 'package:simplenotes/services/note_service.dart';
import 'package:simplenotes/services/category_service.dart';
import 'package:simplenotes/services/search_service.dart';
import 'package:simplenotes/routes/app_routes.dart';
import 'package:simplenotes/screens/note_list_screen.dart';
import 'package:simplenotes/screens/note_detail_screen.dart';
import 'package:simplenotes/screens/category_management_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SimpleNotes Integration Tests', () {
    late HiveStorageService storageService;
    late NoteService noteService;
    late CategoryService categoryService;
    late SearchService searchService;
    late NoteProvider noteProvider;
    late CategoryProvider categoryProvider;
    late SearchProvider searchProvider;
    late ThemeProvider themeProvider;

    setUpAll(() async {
      // Initialize storage service
      storageService = HiveStorageService();
      await storageService.initialize();

      // Initialize services
      noteService = NoteService(storageService);
      categoryService = CategoryService(storageService);
      searchService = SearchService(storageService);

      // Initialize providers
      noteProvider = NoteProvider(noteService);
      categoryProvider = CategoryProvider(categoryService);
      searchProvider = SearchProvider(searchService);
      themeProvider = ThemeProvider();
      await themeProvider.initialize();
    });

    tearDownAll(() async {
      // Clean up storage
      final allNotes = await storageService.getAllNotes();
      for (final note in allNotes) {
        await storageService.deleteNote(note.id);
      }
      final allCategories = await storageService.getAllCategories();
      for (final category in allCategories) {
        await storageService.deleteCategory(category.id);
      }
      await storageService.close();
    });

    Widget _buildApp({String? initialRoute}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: noteProvider),
          ChangeNotifierProvider.value(value: categoryProvider),
          ChangeNotifierProvider.value(value: searchProvider),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: MaterialApp(
          initialRoute: initialRoute,
          home: const NoteListScreen(),
          routes: {
            AppRoutes.noteDetail: (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is String) {
                return NoteDetailScreen(noteId: args);
              }
              return const NoteDetailScreen(noteId: null);
            },
            AppRoutes.categoryManagement: (context) => const CategoryManagementScreen(),
          },
        ),
      );
    }

    testWidgets('Test creating a note', (WidgetTester tester) async {
      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Find and tap the floating action button to create a note
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify we're on the note detail screen
      expect(find.text('New Note'), findsOneWidget);

      // Find title and content fields
      final titleFields = find.byType(TextFormField);
      expect(titleFields, findsAtLeastNWidgets(2));
      
      final titleField = titleFields.first;
      final contentField = titleFields.last;

      // Enter note title
      await tester.enterText(titleField, 'Test Note Title');
      await tester.pumpAndSettle();

      // Enter note content
      await tester.enterText(contentField, 'This is test note content');
      await tester.pumpAndSettle();

      // Find and tap the save button
      final saveButton = find.text('Create');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're back on the note list screen
      expect(find.text('Notes'), findsOneWidget);

      // Verify the note appears in the list
      expect(find.text('Test Note Title'), findsOneWidget);

      // Clean up: delete the test note
      final notes = await noteProvider.getNotes();
      final testNote = notes.firstWhere((n) => n.title == 'Test Note Title');
      await noteProvider.deleteNote(testNote.id);
    });

    testWidgets('Test editing a note', (WidgetTester tester) async {
      // Create a note first
      final note = await noteProvider.createNote(
        title: 'Original Title',
        content: 'Original Content',
      );

      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Find and tap the note card
      final noteCard = find.text('Original Title');
      expect(noteCard, findsOneWidget);
      await tester.tap(noteCard);
      await tester.pumpAndSettle();

      // Verify we're on the note detail screen
      expect(find.text('Note Details'), findsOneWidget);

      // Find title and content fields
      final titleFields = find.byType(TextFormField);
      expect(titleFields, findsAtLeastNWidgets(2));
      
      final titleField = titleFields.first;
      final contentField = titleFields.last;

      // Clear and update title
      await tester.enterText(titleField, 'Updated Title');
      await tester.pumpAndSettle();

      // Clear and update content
      await tester.enterText(contentField, 'Updated Content');
      await tester.pumpAndSettle();

      // Find and tap the save button
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're back on the note list screen
      expect(find.text('Notes'), findsOneWidget);

      // Verify the updated note appears
      expect(find.text('Updated Title'), findsOneWidget);
      expect(find.text('Original Title'), findsNothing);

      // Clean up: delete the test note
      await noteProvider.deleteNote(note.id);
    });

    testWidgets('Test deleting a note', (WidgetTester tester) async {
      // Create a note first
      final note = await noteProvider.createNote(
        title: 'Note To Delete',
        content: 'This note will be deleted',
      );

      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Find and tap the note card
      final noteCard = find.text('Note To Delete');
      expect(noteCard, findsOneWidget);
      await tester.tap(noteCard);
      await tester.pumpAndSettle();

      // Verify we're on the note detail screen
      expect(find.text('Note Details'), findsOneWidget);

      // Find and tap the delete button
      final deleteButton = find.byIcon(Icons.delete_outline);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Confirm deletion in dialog
      final confirmDeleteButton = find.text('Delete');
      expect(confirmDeleteButton, findsOneWidget);
      await tester.tap(confirmDeleteButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're back on the note list screen
      expect(find.text('Notes'), findsOneWidget);

      // Verify the note is no longer in the list
      expect(find.text('Note To Delete'), findsNothing);
    });

    testWidgets('Test creating a category', (WidgetTester tester) async {
      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Navigate to category management screen
      final categoryButton = find.byIcon(Icons.category);
      expect(categoryButton, findsOneWidget);
      await tester.tap(categoryButton);
      await tester.pumpAndSettle();

      // Verify we're on the category management screen
      expect(find.text('Manage Categories'), findsOneWidget);

      // Find and tap the floating action button to create a category
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify the create category dialog is shown
      expect(find.text('Create Category'), findsOneWidget);

      // Find the category name field
      final nameField = find.byType(TextFormField).first;
      expect(nameField, findsOneWidget);

      // Enter category name
      await tester.enterText(nameField, 'Test Category');
      await tester.pumpAndSettle();

      // Find and tap the create button
      final createButton = find.text('Create');
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify the category appears in the list
      expect(find.text('Test Category'), findsOneWidget);

      // Clean up: delete the test category
      final categories = await categoryProvider.getCategories();
      final testCategory = categories.firstWhere((c) => c.name == 'Test Category');
      await categoryProvider.deleteCategory(testCategory.id, reassignToCategoryId: null);
    });

    testWidgets('Test filtering notes by category', (WidgetTester tester) async {
      // Create a category first
      final category = await categoryProvider.createCategory(
        name: 'Filter Category',
        color: '#2196F3',
      );

      // Create notes with and without category
      final noteWithCategory = await noteProvider.createNote(
        title: 'Note With Category',
        content: 'This note has a category',
        categoryId: category.id,
      );

      final noteWithoutCategory = await noteProvider.createNote(
        title: 'Note Without Category',
        content: 'This note has no category',
      );

      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify both notes are visible
      expect(find.text('Note With Category'), findsOneWidget);
      expect(find.text('Note Without Category'), findsOneWidget);

      // Open category filter dialog
      final filterButton = find.byIcon(Icons.filter_list);
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Select the category from the filter dialog
      final categoryOption = find.text('Filter Category');
      expect(categoryOption, findsOneWidget);
      await tester.tap(categoryOption);
      await tester.pumpAndSettle();

      // Verify only the note with category is visible
      expect(find.text('Note With Category'), findsOneWidget);
      expect(find.text('Note Without Category'), findsNothing);

      // Clear the filter by tapping the close icon on the filter chip
      final filterChip = find.text('Category: Filter Category');
      expect(filterChip, findsOneWidget);
      final clearFilterButton = find.byIcon(Icons.close);
      expect(clearFilterButton, findsOneWidget);
      await tester.tap(clearFilterButton);
      await tester.pumpAndSettle();

      // Verify both notes are visible again
      expect(find.text('Note With Category'), findsOneWidget);
      expect(find.text('Note Without Category'), findsOneWidget);

      // Clean up
      await noteProvider.deleteNote(noteWithCategory.id);
      await noteProvider.deleteNote(noteWithoutCategory.id);
      await categoryProvider.deleteCategory(category.id, reassignToCategoryId: null);
    });

    testWidgets('Test searching notes', (WidgetTester tester) async {
      // Create test notes
      final note1 = await noteProvider.createNote(
        title: 'Shopping List',
        content: 'Buy groceries and milk',
      );

      final note2 = await noteProvider.createNote(
        title: 'Meeting Notes',
        content: 'Discuss project timeline',
      );

      final note3 = await noteProvider.createNote(
        title: 'Recipe Ideas',
        content: 'Try new pasta recipes',
      );

      // Build app
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Wait for initial load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify all notes are visible
      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsOneWidget);
      expect(find.text('Recipe Ideas'), findsOneWidget);

      // Find the search bar (TextField)
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Enter search query
      await tester.enterText(searchField, 'Shopping');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Wait for search debounce and completion
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify only matching note is visible
      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsNothing);
      expect(find.text('Recipe Ideas'), findsNothing);

      // Clear search using the clear button
      final clearButton = find.byIcon(Icons.clear);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      } else {
        // Clear by entering empty text if clear button not found
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Verify all notes are visible again
      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsOneWidget);
      expect(find.text('Recipe Ideas'), findsOneWidget);

      // Test searching by content
      await tester.enterText(searchField, 'pasta');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify only matching note is visible
      expect(find.text('Recipe Ideas'), findsOneWidget);
      expect(find.text('Shopping List'), findsNothing);
      expect(find.text('Meeting Notes'), findsNothing);

      // Clean up
      await noteProvider.deleteNote(note1.id);
      await noteProvider.deleteNote(note2.id);
      await noteProvider.deleteNote(note3.id);
    });
  });
}
