import 'dart:convert';
import 'dart:io';

class TestResourceUtil {
  static Future<dynamic> readJsonResource({required String fileName}) async {
    final file = File('test/resources/$fileName.json');
    return jsonDecode(await file.readAsString());
  }
}
