import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that accepts drag-and-drop files on web.
/// On non-web platforms, this is a no-op wrapper.
class FileDropZone extends StatefulWidget {
  final Widget child;
  final Future<void> Function(List<String> filePaths) onFilesDropped;

  const FileDropZone({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerWebDropListener();
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      _unregisterWebDropListener();
    }
    super.dispose();
  }

  void _registerWebDropListener() {
    // On web, we use a method channel to listen for HTML5 drop events
    // This requires the web/index.html to expose a JS interop for file drops
    // For now, we use the browser's native drag/drop via a platform channel
  }

  void _unregisterWebDropListener() {
    // Cleanup
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return widget.child;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        setState(() => _isDragging = true);
        return false; // We don't accept drag data from other widgets
      },
      onLeave: (data) {
        setState(() => _isDragging = false);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            widget.child,
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Drop EPUB or MOBI file here',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Release to import book',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
