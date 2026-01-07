import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/page_content.dart';
import '../models/app_settings.dart';

class PaginationUtil {
  static List<PageContent> paginateText({
    required String text,
    required Size pageSize,
    required AppSettings settings,
    required BuildContext context,
  }) {
    final pages = <PageContent>[];
    
    // Handle empty text
    if (text.trim().isEmpty) {
      pages.add(PageContent(
        originalText: '',
        pageNumber: 1,
        totalPages: 1,
      ));
      return pages;
    }
    
    // Validate page size
    if (pageSize.width <= 0 || pageSize.height <= 0) {
      // Return single page with all text if size is invalid
      pages.add(PageContent(
        originalText: text,
        pageNumber: 1,
        totalPages: 1,
      ));
      return pages;
    }
    
    // Calculate text metrics
    final textStyle = TextStyle(
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize.toDouble(),
      height: settings.lineHeight,
    );
    
    final textPainter = TextPainter(
      text: TextSpan(text: 'A', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final lineHeight = textPainter.height;
    if (lineHeight <= 0) {
      // Fallback if line height calculation fails
      pages.add(PageContent(
        originalText: text,
        pageNumber: 1,
        totalPages: 1,
      ));
      return pages;
    }
    
    final margin = _getMarginSize(settings.marginSize);
    final availableWidth = (pageSize.width - (margin * 2)).clamp(1.0, double.infinity);
    final availableHeight = (pageSize.height - (margin * 2)).clamp(1.0, double.infinity);
    
    final linesPerPage = (availableHeight / lineHeight).floor().clamp(1, 10000);
    final maxCharsPerLine = _estimateCharsPerLine(availableWidth, textStyle);
    
    // Split text into paragraphs
    final paragraphs = text.split(RegExp(r'\n\s*\n'));
    
    int currentPage = 1;
    StringBuffer currentPageText = StringBuffer();
    int currentLines = 0;
    
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        if (currentPageText.isNotEmpty) {
          currentPageText.write('\n\n');
          currentLines += 2;
        }
        continue;
      }
      
      // Split paragraph into words
      final words = paragraph.split(RegExp(r'\s+'));
      final paragraphBuffer = StringBuffer();
      
      for (final word in words) {
        final testText = paragraphBuffer.isEmpty 
            ? word 
            : '${paragraphBuffer.toString()} $word';
        
        // Estimate lines for this text
        final estimatedLines = _estimateLines(testText, availableWidth, textStyle);
        
        if (currentLines + estimatedLines > linesPerPage && currentPageText.isNotEmpty) {
          // Save current page and start new one
          pages.add(PageContent(
            originalText: currentPageText.toString().trim(),
            pageNumber: currentPage,
            totalPages: 0, // Will be set later
          ));
          
          currentPage++;
          currentPageText.clear();
          currentLines = 0;
        }
        
        if (paragraphBuffer.isNotEmpty) {
          paragraphBuffer.write(' ');
        }
        paragraphBuffer.write(word);
      }
      
      // Add paragraph to current page
      if (currentPageText.isNotEmpty) {
        currentPageText.write('\n\n');
        currentLines += 2;
      }
      
      final paragraphText = paragraphBuffer.toString();
      final paragraphLines = _estimateLines(paragraphText, availableWidth, textStyle);
      
      if (currentLines + paragraphLines > linesPerPage && currentPageText.isNotEmpty) {
        // Move to next page
        pages.add(PageContent(
          originalText: currentPageText.toString().trim(),
          pageNumber: currentPage,
          totalPages: 0,
        ));
        
        currentPage++;
        currentPageText.clear();
        currentLines = 0;
      }
      
      currentPageText.write(paragraphText);
      currentLines += paragraphLines;
    }
    
    // Add last page
    if (currentPageText.isNotEmpty) {
      pages.add(PageContent(
        originalText: currentPageText.toString().trim(),
        pageNumber: currentPage,
        totalPages: 0,
      ));
    }
    
    // Update total pages
    final totalPages = pages.length;
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(totalPages: totalPages);
    }
    
    return pages;
  }

  static double _getMarginSize(int marginSize) {
    switch (marginSize) {
      case 0:
        return 8.0;
      case 1:
        return 16.0;
      case 2:
        return 24.0;
      case 3:
        return 32.0;
      case 4:
        return 40.0;
      default:
        return 24.0;
    }
  }

  static int _estimateCharsPerLine(double width, TextStyle style) {
    // Rough estimation: average character width is about 60% of font size
    final avgCharWidth = style.fontSize! * 0.6;
    return (width / avgCharWidth).floor();
  }

  static int _estimateLines(String text, double width, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    
    textPainter.layout(maxWidth: width);
    
    final lineMetrics = textPainter.computeLineMetrics();
    if (lineMetrics.isNotEmpty) {
      return lineMetrics.length;
    }
    
    // Fallback: estimate based on height
    final lineHeight = style.height ?? 1.0;
    final fontSize = style.fontSize ?? 16.0;
    final estimatedLineHeight = fontSize * lineHeight;
    return (textPainter.height / estimatedLineHeight).ceil().clamp(1, 1000);
  }
}
