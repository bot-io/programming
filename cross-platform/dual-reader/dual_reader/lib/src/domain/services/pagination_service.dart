import 'package:flutter/widgets.dart';

abstract class PaginationService {
  /// Calculates page breaks for a given text.
  /// Returns a list of strings, where each string represents a page.
  List<String> paginateText({
    required String text,
    required BoxConstraints constraints,
    required TextStyle textStyle,
    double lineHeight,
    EdgeInsets padding,
  });
}

