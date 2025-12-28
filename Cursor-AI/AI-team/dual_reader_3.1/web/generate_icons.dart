import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Generate PWA icons for Dual Reader 3.1
/// Run with: dart run web/generate_icons.dart

const List<int> iconSizes = [16, 32, 72, 96, 128, 144, 152, 192, 384, 512];
const Color backgroundColor = Color(0xFF1976D2); // Material Blue
const Color foregroundColor = Colors.white;

Future<void> main() async {
  print('Generating PWA icons for Dual Reader 3.1...\n');
  
  final iconsDir = Directory('web/icons');
  if (!iconsDir.existsSync()) {
    iconsDir.createSync(recursive: true);
  }
  
  // Generate all icon sizes
  for (final size in iconSizes) {
    await generateIcon(size, 'web/icons/icon-$size.png');
  }
  
  // Generate favicon
  await generateIcon(32, 'web/favicon.png');
  
  print('\n✓ All icons generated successfully!');
}

Future<void> generateIcon(int size, String path) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sizeRect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    
    // Draw background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(sizeRect, bgPaint);
    
    // Draw book icon (simplified representation)
    final iconPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size / 16;
    
    final padding = size * 0.2;
    final iconSize = size - (padding * 2);
    final iconRect = Rect.fromLTWH(
      padding,
      padding,
      iconSize,
      iconSize,
    );
    
    // Draw open book (two pages)
    final pageWidth = iconSize / 2;
    
    // Left page
    canvas.drawRect(
      Rect.fromLTWH(iconRect.left, iconRect.top, pageWidth, iconRect.height),
      iconPaint,
    );
    
    // Right page
    canvas.drawRect(
      Rect.fromLTWH(
        iconRect.left + pageWidth,
        iconRect.top,
        pageWidth,
        iconRect.height,
      ),
      iconPaint,
    );
    
    // Center binding line
    final centerX = iconRect.left + pageWidth;
    canvas.drawLine(
      Offset(centerX, iconRect.top),
      Offset(centerX, iconRect.bottom),
      iconPaint,
    );
    
    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null) {
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      print('✓ Created: $path ($size x $size)');
    }
  } catch (e) {
    print('✗ Error creating $path: $e');
  }
}
