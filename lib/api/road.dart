import 'dart:convert';
import 'config.dart';
import 'package:http/http.dart' as http;

class RoadApi {
  static Future<Map<String, dynamic>> searchRoute({
    required List<double> start,
    required List<double> end,
    int? timestamp
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/route/search').replace(queryParameters: {
        'start_at': (timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
        'end_at': '0',
        'src_loc': start.map((e) => e.toString()).toList(),
        'dst_loc': end.map((e) => e.toString()).toList(),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search route data');
    }
  }
}