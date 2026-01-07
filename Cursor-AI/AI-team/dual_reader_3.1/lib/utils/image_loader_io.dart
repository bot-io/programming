// Platform-specific implementation for mobile/desktop
import 'dart:io' as io;
import 'package:flutter/material.dart';

Widget loadCoverImageFromFile(String imagePath, ThemeData theme) {
  return Image.file(
    io.File(imagePath),
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
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
    },
  );
}
