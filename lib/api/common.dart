import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class CommonApi {
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