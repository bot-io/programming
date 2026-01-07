class PageContent {
  final String originalText;
  final String? translatedText;
  final int pageNumber;
  final int totalPages;
  final bool isTranslated;
  final String? originalHtml; // HTML content for rich text rendering
  final String? translatedHtml; // Translated HTML content

  PageContent({
    required this.originalText,
    this.translatedText,
    required this.pageNumber,
    required this.totalPages,
    this.isTranslated = false,
    this.originalHtml,
    this.translatedHtml,
  });

  PageContent copyWith({
    String? originalText,
    String? translatedText,
    int? pageNumber,
    int? totalPages,
    bool? isTranslated,
    String? originalHtml,
    String? translatedHtml,
  }) {
    return PageContent(
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      pageNumber: pageNumber ?? this.pageNumber,
      totalPages: totalPages ?? this.totalPages,
      isTranslated: isTranslated ?? this.isTranslated,
      originalHtml: originalHtml ?? this.originalHtml,
      translatedHtml: translatedHtml ?? this.translatedHtml,
    );
  }
}
