import 'package:epubx/epubx.dart';

abstract class EpubParserService {
  Future<EpubBook> parseEpub(List<int> bytes);
}

