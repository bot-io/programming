import 'package:mobi/mobi.dart'; // Assuming mobi package is used

abstract class MobiParserService {
  Future<MobiBook> parseMobi(List<int> bytes);
}

