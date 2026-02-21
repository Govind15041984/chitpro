import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';

class MyChitsApi {
  static Future<List<dynamic>> fetchChits() async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-groups'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load chits");
    }

    return jsonDecode(res.body);
  }
}
