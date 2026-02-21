import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth_storage.dart';
import 'config_api.dart';

class ApiClient {
  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await AuthStorage.instance.getToken();

    return http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(String path) async {
    final token = await AuthStorage.instance.getToken();

    return http.get(
      Uri.parse('$kBaseUrl$path'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }
}
