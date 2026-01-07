import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';

// Conditional imports
import 'image_loader_stub.dart' if (dart.library.io) 'image_loader_io.dart' as platform;

Widget loadCoverImage(String? imagePath, ThemeData theme) {
  if (imagePath == null) {
    return _buildPlaceholder(theme);
  }

  if (kIsWeb) {
    // On web, handle web:// paths specially
    if (imagePath.startsWith('web://covers/')) {
      return _WebCoverImage(imagePath: imagePath, theme: theme);
    }
    // Try network image if it's a URL
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(theme);
        },
      );
    }
    return _buildPlaceholder(theme);
  } else {
    // On mobile/desktop, handle file paths
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(theme);
        },
      );
    } else {
      // Use platform-specific file loader
      return platform.loadCoverImageFromFile(imagePath, theme);
    }
  }
}

class _WebCoverImage extends StatefulWidget {
  final String imagePath;
  final ThemeData theme;

  const _WebCoverImage({
    Key? key,
    required this.imagePath,
    required this.theme,
  }) : super(key: key);

  @override
  State<_WebCoverImage> createState() => _WebCoverImageState();
}

class _WebCoverImageState extends State<_WebCoverImage> {
  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bookId = widget.imagePath
          .replaceFirst('web://covers/', '')
          .replaceAll('.jpg', '');
      final coversBox = await Hive.openBox<String>('book_covers_base64');
      final base64Data = coversBox.get(bookId);
      if (base64Data != null) {
        final imageData = base64Decode(base64Data);
        if (mounted) {
          setState(() {
            _imageData = imageData;
          });
        }
      }
    } catch (e) {
      print('Error loading web cover image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageData != null) {
      return Image.memory(
        _imageData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(widget.theme);
        },
      );
    }
    return _buildPlaceholder(widget.theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Icon(
        Icons.book,
        size: 40,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

Widget _buildPlaceholder(ThemeData theme) {
  return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceVariant,
    ),
    child: Icon(
      Icons.book,
      size: 40,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
