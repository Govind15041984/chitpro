import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';
import '../../chit_create/data/chit_create_api.dart';


class ChitGroupApi {
  static Future<Map<String, dynamic>> getSummary(String chitGroupId) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/summary'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    } else {
      throw ApiException(res.statusCode, res.body);
    }

  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // -----------------------------------------
  // Start Month (create monthly ledger entries)
  // -----------------------------------------
  static Future<Map<String, dynamic>> startMonth(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/start-month'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Start Month failed: ${res.body}");
    }

    return jsonDecode(res.body);
  }

  // -----------------------------------------
// Check if current month is started (ledger exists)
// -----------------------------------------
  static Future<Map<String, dynamic>> isMonthStarted(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/current-month-started'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to check month status: ${res.body}");
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReserveSummary(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/reserve'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to load reserve summary");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> saveGroupLink(String groupId, String url) async {
    final response = await http.post(
      Uri.parse("$kBaseUrl/GroupLink/"),
      body: jsonEncode({
        "chit_group_id": groupId,
        "platform": "whatsapp",
        "link_url": url,
        "is_active": true
      }),
      headers: {"Content-Type": "application/json"},
    );
    if (response.statusCode != 200) throw Exception("Failed to save link");
  }

  static Future<void> updateNextRunDate(String chitGroupId, String isoDate) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/update-next-run-date'),
      headers: await _headers(),
      body: jsonEncode({"next_run_date": isoDate}),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to update next run date");
    }
  }


}
