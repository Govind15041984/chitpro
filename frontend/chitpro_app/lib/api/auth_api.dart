import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_api.dart';

class AuthApi {

  static Future<bool> checkMobile(String mobileNumber) async {
    final url = Uri.parse('$kBaseUrl/admin/check-mobile');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "mobile_number": mobileNumber,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['exists'] == true;
    } else {
      throw Exception("Failed to check mobile number");
    }
  }

  static Future<String> login(String mobileNumber, String pin) async {
    final url = Uri.parse('$kBaseUrl/admin/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "mobile_number": mobileNumber,
        "pin": pin,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception("Invalid mobile or PIN");
    }
  }

  static Future<String> register(String name, String mobile, String pin) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/admin/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "name": name,
        "mobile_number": mobile,
        "pin": pin,
      }),
    );

    print("REGISTER RAW RESPONSE = ${response.body}");

    if (response.statusCode != 200) {
      throw Exception("Registration failed");
    }

    final data = jsonDecode(response.body);
    print("PARSED TOKEN = ${data['access_token']}");

    return data['access_token'];
  }

}
