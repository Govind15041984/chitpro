import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth_storage.dart';
import 'config_api.dart';

class DashboardApi {
  static Future<Map<String, dynamic>> loadDashboard() async {
    final token = await AuthStorage.instance.getToken();

    if (token == null) {
      throw Exception("No authentication token found.");
    }

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // We now call the SINGLE consolidated dashboard endpoint
    final response = await http.get(
      Uri.parse('$kBaseUrl/dashboard'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Log for debugging: remove this once you see data flowing
      print("Dashboard Data Received: $data");

      return data;
    } else {
      print("Dashboard Error: ${response.statusCode} - ${response.body}");
      throw Exception("Failed to load dashboard data");
    }
  }
}