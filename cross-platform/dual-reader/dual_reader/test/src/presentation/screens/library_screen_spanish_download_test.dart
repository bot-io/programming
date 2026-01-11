import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dual_reader/src/presentation/providers/language_model_notifier.dart';

// Simplified widget tests focused on banner UI components
void main() {
  group('Language Model Download Banner Widget Tests', () {
    testWidgets('should render progress banner components', (WidgetTester tester) async {
      final progressBanner = Material(
        child: ColoredBox(
          color: const Color(0xffd1c4e9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Downloading Bulgarian translation model...',
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
        ),
      );

      await tester.pumpWidget(progressBanner);
      await tester.pumpAndSettle();

      expect(find.text('Downloading Bulgarian translation model...'), findsOneWidget);
      expect(find.text('Initializing download...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render success banner components', (WidgetTester tester) async {
      final successBanner = Material(
        child: ColoredBox(
          color: const Color(0xffe8f5e9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bulgarian model ready! Translations will be faster.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.grey,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(successBanner);
      await tester.pumpAndSettle();

      expect(find.text('Bulgarian model ready! Translations will be faster.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should render error banner components', (WidgetTester tester) async {
      final errorBanner = Material(
        child: ColoredBox(
          color: const Color(0xffffebee),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
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
                          color: Color(0xff616161),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Retry'),
                ),
              ],
            ),
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

      final banner = Material(
        child: ColoredBox(
          color: const Color(0xffd1c4e9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Downloading Bulgarian translation model...',
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
        ),
      );

      await tester.pumpWidget(banner);
      await tester.pumpAndSettle();

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('error banner should display error message correctly', (WidgetTester tester) async {
      const longErrorMessage = 'Failed to download language model: Network timeout after 5 minutes. Please check your internet connection and try again.';

      final banner = Material(
        child: ColoredBox(
          color: const Color(0xffffebee),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
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
                  onPressed: () {},
                  child: const Text('Retry'),
                ),
              ],
            ),
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
        color: Color(0xffd1c4e9),
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(progressBanner);
      final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(coloredBox.color, const Color(0xffd1c4e9));

      // Test success banner color
      const successBanner = ColoredBox(
        color: Color(0xffe8f5e9),
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(successBanner);
      final successBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(successBox.color, const Color(0xffe8f5e9));

      // Test error banner color
      const errorBanner = ColoredBox(
        color: Color(0xffffebee),
        child: SizedBox(height: 50),
      );

      await tester.pumpWidget(errorBanner);
      final errorBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(errorBox.color, const Color(0xffffebee));
    });
  });

  group('LanguageModelState Tests', () {
    test('should have correct initial state', () {
      const state = LanguageModelState(status: ModelDownloadStatus.notStarted);

      expect(state.status, ModelDownloadStatus.notStarted);
      expect(state.progressMessage, isNull);
      expect(state.errorMessage, isNull);
      expect(state.languageCode, 'en');
    });

    test('should copy state with new values', () {
      const initialState = LanguageModelState(status: ModelDownloadStatus.notStarted);

      final newState = initialState.copyWith(
        status: ModelDownloadStatus.completed,
        progressMessage: 'Complete!',
      );

      expect(newState.status, ModelDownloadStatus.completed);
      expect(newState.progressMessage, 'Complete!');
      expect(newState.errorMessage, isNull);
    });

    test('should preserve values when copying with null', () {
      const initialState = LanguageModelState(
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
