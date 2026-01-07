import 'package:epubx/epubx.dart';
import 'package:dual_reader/src/domain/services/epub_parser_service.dart';

class EpubParserServiceImpl implements EpubParserService {
  @override
  Future<EpubBook> parseEpub(List<int> bytes) async {
    return await EpubReader.readBook(bytes);
  }
}
