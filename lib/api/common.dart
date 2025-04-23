import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class CommonApi {
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.get(
      Uri.parse('${Config.baseURL}/common/login').replace(queryParameters: {
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to login');
    }
  }


  static Future<Map<String, dynamic>> getUserData() async {
    final uri = Uri.parse('${Config.baseURL}/map/info');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load map info');
    }
  }
}