import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class MapApi {
  static Future<Map<String, dynamic>> getMapInfo({
    int? timestamp
  }) async {
    final uri = Uri.parse('${Config.baseURL}/map/info').replace(queryParameters: {
      'timestamp': (timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    });
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load map info');
    }
  }

  static Future<Map<String, dynamic>> getTraffic({
    int? timestamp
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/map/traffic').replace(queryParameters: {
        'timestamp': (timestamp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load traffic info');
    }
  }

  static Future<Map<String, dynamic>> getWeather() async {
    final uri = Uri.parse('${Config.baseURL}/map/weather');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load weather data');
    }
  }
} 