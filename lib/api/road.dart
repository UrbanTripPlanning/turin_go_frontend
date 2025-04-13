import 'dart:convert';
import 'config.dart';
import 'package:http/http.dart' as http;

class RoadApi {
  static Future<Map<String, dynamic>> searchRoute({
    required List<double> start,
    required List<double> end,
    int? startAt,
    int? endAt,
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/route/search').replace(queryParameters: {
        'start_at': (startAt ?? 0).toString(),
        'end_at': (endAt ?? 0).toString(),
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