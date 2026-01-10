import 'dart:io';

void main() {
  // From chunk_translation_service.dart _combinePagesToChunk
  final pages = ['P0-P1', 'P0-P2', 'P0-P3', 'P1-P1', 'P2-P1', 'P2-P2'];
  
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
  
  // From chunk_translation_service.dart _calculatePageBreakOffsets
  final offsets = <int>[];
  int currentOffset = 0;
  
  for (int i = 0; i < pages.length; i++) {
    currentOffset += pages[i].length;
    offsets.add(currentOffset);
    print('Page $i offset: $currentOffset (after "${pages[i]}")');
    
    if (i < pages.length - 1) {
      currentOffset += 2; // '\n\n'
    }
  }
  
  print('All offsets: $offsets');
}
