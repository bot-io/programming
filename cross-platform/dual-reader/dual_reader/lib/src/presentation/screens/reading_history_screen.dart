import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dual_reader/src/core/di/injection_container.dart';
import 'package:dual_reader/src/domain/entities/reading_history_entity.dart';
import 'package:dual_reader/src/domain/repositories/reading_history_repository.dart';
import 'package:dual_reader/src/domain/usecases/get_reading_history_usecase.dart';

/// Provider that loads reading history.
final readingHistoryProvider = FutureProvider<List<ReadingHistoryEntity>>((ref) {
  final useCase = sl<GetReadingHistoryUseCase>();
  return useCase(limit: 100);
});

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(readingHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear history',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text(
                    'Are you sure you want to clear all reading history? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final repo = sl<ReadingHistoryRepository>();
                await repo.clearHistory();
                ref.invalidate(readingHistoryProvider);
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text('Failed to load history', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$e', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text(
                    'No reading history yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start reading to track your progress',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<ReadingHistoryEntity>>{};
          for (final entry in entries) {
            final dateStr = _formatDate(entry.endedAt);
            grouped.putIfAbsent(dateStr, () => []).add(entry);
          }

          return ListView.builder(
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final items = grouped[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      date,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...items.map((entry) => _HistoryTile(entry: entry)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _HistoryTile extends StatelessWidget {
  final ReadingHistoryEntity entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = entry.duration;
    final durationStr = duration.inMinutes > 0
        ? '${duration.inMinutes}m'
        : '${duration.inSeconds}s';

    return ListTile(
      leading: const Icon(Icons.auto_stories),
      title: Text(
        entry.bookTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Pages ${entry.startPage + 1}–${entry.endPage + 1} ($durationStr)',
      ),
      trailing: Text(
        _formatTime(entry.endedAt),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
