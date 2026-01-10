import 'dart:io';

void main() {
  // Test case from translation_chunk_test.dart
  final pages = ['P0-P1\n\nP0-P2\n\nP0-P3', 'P1-P1', 'P2-P1\n\nP2-P2'];
  
  final buffer = StringBuffer();
  for (int i = 0; i < pages.length; i++) {
    if (i > 0) {
      buffer.write('\n\n');
    }
    buffer.write(pages[i]);
  }
  final combined = buffer.toString();
  print('Combined: "$combined"');
  print('Length: ${combined.length}');
  
  final offsets = <int>[];
  int currentOffset = 0;
  
  for (int i = 0; i < pages.length; i++) {
    currentOffset += pages[i].length;
    offsets.add(currentOffset);
    print('Page $i: "${pages[i]}" length=${pages[i].length} offset=$currentOffset');
    
    if (i < pages.length - 1) {
      currentOffset += 2; // '\n\n'
    }
  }
  
  print('All offsets: $offsets');
  
  // Now let's extract each page
  for (int i = 0; i < pages.length; i++) {
    final start = i == 0 ? 0 : offsets[i - 1] + 2;
    final end = offsets[i];
    final extracted = combined.substring(start, end);
    print('Page $i extraction: "$extracted" (start=$start, end=$end)');
  }
}
