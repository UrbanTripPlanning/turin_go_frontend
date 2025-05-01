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

  static Future<Map<String, dynamic>> saveRoute({
    required String userId,
    required List<double> start,
    required List<double> end,
    required int spendTime,
    required int timeMode,
    required String startName,
    required String endName,
    required int routeMode,
    String? planId,
    int? startAt,
    int? endAt,
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/route/save').replace(queryParameters: {
        'plan_id': planId ?? '',
        'user_id': userId.toString(),
        'start_at': (startAt ?? 0).toString(),
        'end_at': (endAt ?? 0).toString(),
        'src_loc': start.map((e) => e.toString()).toList(),
        'dst_loc': end.map((e) => e.toString()).toList(),
        'src_name': startName,
        'dst_name': endName,
        'spend_time': spendTime.toString(),
        'time_mode': timeMode.toString(),
        'route_mode': routeMode.toString()
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to save route data');
    }
  }

  static Future<Map<String, dynamic>> listRoute({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/route/list').replace(queryParameters: {
        'user_id': userId.toString(),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to list route data');
    }
  }

  static Future<Map<String, dynamic>> afftectedRoute({
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/route/list/affected').replace(queryParameters: {
        'user_id': userId.toString(),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to list affected route data');
    }
  }
}