import 'dart:convert';
import 'config.dart';
import 'package:http/http.dart' as http;

class RoadApi {
  static Future<Map<String, dynamic>> searchRoad({
    required String start,
    required String end,
    int? timestamp
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/road').replace(queryParameters: {
        'start': start,
        'end': end,
        'timestamp': timestamp ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load road data');
    }
  }
}