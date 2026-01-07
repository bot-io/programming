import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// A widget that renders HTML content with preserved formatting
/// Supports: bold, italic, headings, paragraphs, lists, line breaks
class RichTextRenderer extends StatelessWidget {
  final String htmlContent;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  final EdgeInsets padding;

  const RichTextRenderer({
    Key? key,
    required this.htmlContent,
    required this.baseStyle,
    this.textAlign = TextAlign.left,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (htmlContent.trim().isEmpty) {
      return Text('', style: baseStyle, textAlign: textAlign);
    }

    try {
      final document = html_parser.parse(htmlContent);
      final body = document.body;
      
      if (body == null) {
        // Fallback to plain text if HTML parsing fails
        return Padding(
          padding: padding,
          child: Text(
            htmlContent,
            style: baseStyle,
            textAlign: textAlign,
          ),
        );
      }

      final textSpans = _parseNode(body, baseStyle);
      
      return Padding(
        padding: padding,
        child: Text.rich(
          TextSpan(children: textSpans),
          textAlign: textAlign,
        ),
      );
    } catch (e) {
      // Fallback to plain text on error
      return Padding(
        padding: padding,
        child: Text(
          htmlContent,
          style: baseStyle,
          textAlign: textAlign,
        ),
      );
    }
  }

  List<TextSpan> _parseNode(html_dom.Node node, TextStyle parentStyle) {
    final spans = <TextSpan>[];

    if (node is html_dom.Text) {
      final text = node.text?.trim() ?? '';
      if (text.isNotEmpty) {
        spans.add(TextSpan(
          text: text,
          style: parentStyle,
        ));
      }
    } else if (node is html_dom.Element) {
      final element = node;
      final tagName = element.localName?.toLowerCase() ?? '';

      // Apply styling based on tag
      TextStyle style = parentStyle;

      switch (tagName) {
        case 'b':
        case 'strong':
          style = parentStyle.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'i':
        case 'em':
          style = parentStyle.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'u':
          style = parentStyle.copyWith(decoration: TextDecoration.underline);
          break;
        case 'h1':
          style = parentStyle.copyWith(
            fontSize: (parentStyle.fontSize ?? 16) * 2.0,
            fontWeight: FontWeight.bold,
          );
          break;
        case 'h2':
          style = parentStyle.copyWith(
            fontSize: (parentStyle.fontSize ?? 16) * 1.75,
            fontWeight: FontWeight.bold,
          );
          break;
        case 'h3':
          style = parentStyle.copyWith(
            fontSize: (parentStyle.fontSize ?? 16) * 1.5,
            fontWeight: FontWeight.bold,
          );
          break;
        case 'h4':
          style = parentStyle.copyWith(
            fontSize: (parentStyle.fontSize ?? 16) * 1.25,
            fontWeight: FontWeight.bold,
          );
          break;
        case 'h5':
        case 'h6':
          style = parentStyle.copyWith(
            fontSize: (parentStyle.fontSize ?? 16) * 1.1,
            fontWeight: FontWeight.bold,
          );
          break;
        case 'p':
          // Add spacing before paragraph
          if (spans.isNotEmpty) {
            spans.add(TextSpan(text: '\n\n', style: parentStyle));
          }
          break;
        case 'br':
          spans.add(TextSpan(text: '\n', style: parentStyle));
          break;
        case 'li':
          // List item - add bullet point
          spans.add(TextSpan(text: '• ', style: parentStyle));
          break;
        case 'ul':
        case 'ol':
          // Lists - add spacing
          if (spans.isNotEmpty) {
            spans.add(TextSpan(text: '\n', style: parentStyle));
          }
          break;
        case 'blockquote':
          style = parentStyle.copyWith(
            fontStyle: FontStyle.italic,
            color: parentStyle.color?.withOpacity(0.8),
          );
          spans.add(TextSpan(text: '"', style: style));
          break;
        case 'code':
          style = parentStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withOpacity(0.2),
          );
          break;
        case 'pre':
          style = parentStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.withOpacity(0.2),
          );
          spans.add(TextSpan(text: '\n', style: parentStyle));
          break;
      }

      // Process child nodes
      for (final child in element.nodes) {
        spans.addAll(_parseNode(child, style));
      }

      // Add spacing after certain block elements
      if (['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote'].contains(tagName)) {
        if (spans.isNotEmpty && !spans.last.text?.endsWith('\n\n') ?? true) {
          spans.add(TextSpan(text: '\n\n', style: parentStyle));
        }
      }

      // Close blockquote
      if (tagName == 'blockquote') {
        spans.add(TextSpan(text: '"', style: style));
      }
    }

    return spans;
  }
}

/// A simpler text renderer that handles plain text with basic markdown-like formatting
class FormattedTextRenderer extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  final EdgeInsets padding;

  const FormattedTextRenderer({
    Key? key,
    required this.text,
    required this.baseStyle,
    this.textAlign = TextAlign.left,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return Text('', style: baseStyle, textAlign: textAlign);
    }

    // Detect and render basic formatting patterns
    final spans = _parseFormattedText(text, baseStyle);

    return Padding(
      padding: padding,
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: textAlign,
      ),
    );
  }

  List<TextSpan> _parseFormattedText(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Detect headings (lines starting with #)
      if (line.trim().startsWith('#')) {
        final level = line.trim().split(' ')[0].length;
        final headingText = line.trim().substring(level).trim();
        final headingStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * (2.0 - (level - 1) * 0.25),
          fontWeight: FontWeight.bold,
        );
        spans.add(TextSpan(text: headingText, style: headingStyle));
      } else {
        // Parse inline formatting: **bold**, *italic*, _underline_
        final lineSpans = _parseInlineFormatting(line, baseStyle);
        spans.addAll(lineSpans);
      }
      
      // Add line break (except for last line)
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    
    return spans;
  }

  List<TextSpan> _parseInlineFormatting(String text, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|_.*?_|`.*?`)');
    int lastIndex = 0;
    
    for (final match in regex.allMatches(text)) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }
      
      // Process matched formatting
      final matchedText = match.group(0)!;
      TextStyle? style;
      
      if (matchedText.startsWith('**') && matchedText.endsWith('**')) {
        // Bold
        style = baseStyle.copyWith(fontWeight: FontWeight.bold);
        spans.add(TextSpan(
          text: matchedText.substring(2, matchedText.length - 2),
          style: style,
        ));
      } else if (matchedText.startsWith('*') && matchedText.endsWith('*')) {
        // Italic
        style = baseStyle.copyWith(fontStyle: FontStyle.italic);
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: style,
        ));
      } else if (matchedText.startsWith('_') && matchedText.endsWith('_')) {
        // Underline
        style = baseStyle.copyWith(decoration: TextDecoration.underline);
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: style,
        ));
      } else if (matchedText.startsWith('`') && matchedText.endsWith('`')) {
        // Code
        style = baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.withOpacity(0.2),
        );
        spans.add(TextSpan(
          text: matchedText.substring(1, matchedText.length - 1),
          style: style,
        ));
      } else {
        // No formatting matched, add as plain text
        spans.add(TextSpan(text: matchedText, style: baseStyle));
      }
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }
    
    // If no matches found, return plain text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    
    return spans;
  }
}
