import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class PlaceApi {
  static Future<Map<String, dynamic>> searchPlaces({
    required String name
  }) async {
    final uri = Uri.parse('${Config.baseURL}/place/search').replace(queryParameters: {
      'name': name,
    });
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search places');
    }
  }
}