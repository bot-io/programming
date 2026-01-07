// Stub implementation for web
import 'package:flutter/material.dart';

Widget loadCoverImageFromFile(String imagePath, ThemeData theme) {
  // Web doesn't support file system access
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
