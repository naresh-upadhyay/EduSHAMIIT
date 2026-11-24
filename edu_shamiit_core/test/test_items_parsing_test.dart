import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';

void main() {
  test('Test parsing work items from API response', () async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://localhost:8082/api/v1/work/items?page=1&page_size=100'));
    final resp = await req.close();
    expect(resp.statusCode, 200);

    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final itemsJson = json['items'] as List;

    print('Total raw items from API: ${itemsJson.length}');
    int parsedCount = 0;
    for (int i = 0; i < itemsJson.length; i++) {
      try {
        final item = WorkItemModel.fromJson(itemsJson[i] as Map<String, dynamic>);
        parsedCount++;
      } catch (e, stack) {
        print('FAILED on item $i (${itemsJson[i]['item_number']}): $e');
        print(stack);
        rethrow;
      }
    }
    expect(parsedCount, itemsJson.length);
    print('All $parsedCount items parsed successfully in Dart!');
  });
}
