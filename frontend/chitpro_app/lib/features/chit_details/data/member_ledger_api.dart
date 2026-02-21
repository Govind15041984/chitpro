import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';
import '../../chit_create/data/chit_create_api.dart';

class MemberLedgerApi {
  /// 🔹 STEP2D: Get monthly dues (per slot)
  static Future<List<dynamic>> getMonthlyDues({
    required String chitGroupId,
    required int monthNo,
  }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/member-ledger/group/$chitGroupId/month/$monthNo'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body);
  }


  /// 🔹 STEP2D: Mark a ledger entry as PAID
  static Future<void> markPaid(String ledgerId) async {
    final res = await http.post(
      Uri.parse(
        '$kBaseUrl/member-ledger/$ledgerId/mark-paid',
      ),
      headers: await _headers(),
    );

    _handle(res);
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

  static Future<void> undoPaid(String ledgerId, String reason) async {
    final res = await http.post(
      Uri.parse(
        '$kBaseUrl/member-ledger/$ledgerId/undo-paid?reason=$reason',
      ),
      headers: await _headers(),
    );

    _handle(res);
  }

  static Future<List<dynamic>> getAudit(String ledgerId) async {
    final res = await http.get(
      Uri.parse(
        '$kBaseUrl/member-ledger/$ledgerId/audit',
      ),
      headers: await _headers(),
    );

    return _handle(res);
  }

  static Future<Map<String, dynamic>> collectPartial({
    required String chitGroupId,
    required String personKey,
    required int monthNo,
    required int amount,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/member-ledger/collect'),
      headers: await _headers(),
      body: jsonEncode({
        "chit_group_id": chitGroupId,
        "person_key": personKey,
        "month_no": monthNo,
        "amount": amount,
      }),
    );

    return _handle(res);
  }

  /// 🔹 Get full ledger for a person across all months
  static Future<List<dynamic>> getPersonLedgerAllMonths({
    required String chitGroupId,
    required String personKey,
  }) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/member-ledger/person/$chitGroupId/$personKey'),
      headers: await _headers(),
    );

    return _handle(res);
  }


}
