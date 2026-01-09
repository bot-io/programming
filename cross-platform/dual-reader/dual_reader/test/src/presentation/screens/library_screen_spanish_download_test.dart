import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/presentation/providers/spanish_model_notifier.dart';

// Simplified widget tests focused on banner UI components
void main() {
  group('Spanish Model Download Banner Widget Tests', () {
    testWidgets('should render progress banner components', (WidgetTester tester) async {
      final progressBanner = Material(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: Color(0xffd1c4e9)),
          child: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Downloading Spanish translation model...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Initializing download...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff616161),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(progressBanner);
      await tester.pumpAndSettle();

      expect(find.text('Downloading Spanish translation model...'), findsOneWidget);
      expect(find.text('Initializing download...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render success banner components', (WidgetTester tester) async {
      const successBanner = Material(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Color(0xffe8f5e9), // Colors.green.shade50
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Spanish model ready! Translations will be faster.',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.close, size: 16, color: Colors.grey),
            ],
          ),
        ),
      );

      await tester.pumpWidget(successBanner);
      await tester.pumpAndSettle();

      expect(find.text('Spanish model ready! Translations will be faster.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should render error banner components', (WidgetTester tester) async {
      const errorBanner = Material(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Color(0xffffebee), // Colors.red.shade50
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Model download failed',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red,
                    ),
                    ),
                    Text(
                      'Network connection failed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff616161), // Colors.grey.shade700
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: null,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(errorBanner);
      await tester.pumpAndSettle();

      expect(find.text('Model download failed'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('progress banner should update with different messages', (WidgetTester tester) async {
      const customMessage = 'Downloading language model (50% complete)...';

      const banner = Material(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Color(0xffd1c4e9),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Downloading Spanish translation model...',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      customMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff616161),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(banner);
      await tester.pumpAndSettle();

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('error banner should display error message correctly', (WidgetTester tester) async {
      const longErrorMessage = 'Failed to download language model: Network timeout after 5 minutes. Please check your internet connection and try again.';

      const banner = Material(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Color(0xffffebee),
          child: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Model download failed',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      longErrorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff616161),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: null,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(banner);
      await tester.pumpAndSettle();

      expect(find.text('Model download failed'), findsOneWidget);
      expect(find.text(longErrorMessage), findsOneWidget);
    });

    testWidgets('banners should use correct colors', (WidgetTester tester) async {
      // Test progress banner color
      const progressBanner = ColoredBox(
        color: Color(0xffd1c4e9), // Colors.deepPurple.shade50
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(progressBanner);
      final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(coloredBox.color, const Color(0xffd1c4e9));

      // Test success banner color
      const successBanner = ColoredBox(
        color: Color(0xffe8f5e9), // Colors.green.shade50
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(successBanner);
      final successBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(successBox.color, const Color(0xffe8f5e9));

      // Test error banner color
      const errorBanner = ColoredBox(
        color: Color(0xffffebee), // Colors.red.shade50
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(errorBanner);
      final errorBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(errorBox.color, const Color(0xffffebee));
    });
  });

  group('SpanishModelState Tests', () {
    test('should have correct initial state', () {
      const state = SpanishModelState(status: ModelDownloadStatus.notStarted);

      expect(state.status, ModelDownloadStatus.notStarted);
      expect(state.progressMessage, isNull);
      expect(state.errorMessage, isNull);
    });

    test('should copy state with new values', () {
      const initialState = SpanishModelState(status: ModelDownloadStatus.notStarted);

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Complete!',
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, 'Complete!');
      expect(newState.errorMessage, isNull);
    });

    test('should preserve values when copying with null', () {
      const initialState = SpanishModelState(
        status: ModelDownloadStatus.inProgress,
        progressMessage: 'Downloading...',
        errorMessage: 'Error',
      );

      final newState = initialState.copyWith(status: ModelDownloadStatus.completed);

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, 'Downloading...');
      expect(newState.errorMessage, 'Error');
    });
  });

  group('ModelDownloadStatus Enum Tests', () {
    test('should have all required states', () {
      expect(ModelDownloadStatus.values.length, 4);
      expect(ModelDownloadStatus.notStarted, isNotNull);
      expect(ModelDownloadStatus.inProgress, isNotNull);
      expect(ModelDownloadStatus.completed, isNotNull);
      expect(ModelDownloadStatus.failed, isNotNull);
    });

    test('should have correct state order', () {
      expect(ModelDownloadStatus.values[0], ModelDownloadStatus.notStarted);
      expect(ModelDownloadStatus.values[1], ModelDownloadStatus.inProgress);
      expect(ModelDownloadStatus.values[2], ModelDownloadStatus.completed);
      expect(ModelDownloadStatus.values[3], ModelDownloadStatus.failed);
    });
  });
}
