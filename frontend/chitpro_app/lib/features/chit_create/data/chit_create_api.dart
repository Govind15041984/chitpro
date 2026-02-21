import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../../api/config_api.dart';
import '/../../core/auth_storage.dart';
import '/../../core/jwt_helper.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => "API Error [$statusCode]: $message";
}

class ChitCreateApi {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorage.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    } else {
      throw ApiException(res.statusCode, res.body);
    }
  }

  // -------------------- DRAFT --------------------
  static Future<Map<String, dynamic>> createDraft({
    required String groupName,
    required int chitAmount,
    required int totalMembers,
    required int durationMonths,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/create'),
      headers: await _headers(),
      body: jsonEncode({
        "group_name": groupName,
        "chit_amount": chitAmount,
        "total_slots": totalMembers,
        "duration_months": durationMonths,
        "settings": {},
      }),
    );
    return _handle(res);
  }

  // -------------------- CONFIGURED --------------------
  static Future<Map<String, dynamic>> configureChit(
      String chitGroupId, Map<String, dynamic> settings) async {

    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/configure'),
      headers: await _headers(),
      body: jsonEncode(settings),
    );

    // --- ADD THIS DEBUG BLOCK ---
    if (res.statusCode == 422) {
      debugPrint("🛑 BACKEND 422 ERROR DETAIL:");
      debugPrint(res.body); // This contains the "detail" list with the field name
    }
    // ----------------------------

    return _handle(res);
  }

  // -------------------- ACTIVE --------------------
  static Future<Map<String, dynamic>> activateChit(String chitGroupId) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/activate'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> addMember({
    required String chitGroupId,
    required String name,
    required String mobile,
    required int memberNo,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId'),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "mobile_number": mobile,
        "member_no": memberNo,
      }),
    );
    return _handle(res);
  }

  static Future<void> addMemberWithCatchup({
    required String chitGroupId,
    required String name,
    String? mobile,              // ✅ nullable
    required int memberNo,
    }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/with-catchup'),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "mobile_number": mobile,   // can be null
        "member_no": memberNo,
      }),
    );

    _handle(res);
  }



  static Future<List<dynamic>> listMembers(String chitGroupId) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId'),
      headers: await _headers(),
    );

    final data = _handle(res);

    debugPrint("LIST MEMBERS RAW: $data");

    if (data is List) {
      return List<dynamic>.from(data);
    }

    // fallback if backend accidentally wraps later
    return List<dynamic>.from(data["members"] ?? []);
  }


  static Future<Map<String, dynamic>> addSlotsWithCatchup({
    required String chitGroupId,
    required String name,
    String? mobile,
    required int slotCount,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/slots'),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "mobile_number": mobile,
        "slot_count": slotCount,
      }),
    );

    return _handle(res);
  }

  static Future<List<dynamic>> fetchMemberSlotSummary(
      String chitGroupId) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/summary'),
      headers: await _headers(),
    );

    final data = _handle(res);
    return data;
  }

  // -------------------- RUNNING --------------------
  static Future<Map<String, dynamic>> startChit(String chitGroupId) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/start'),
      headers: await _headers(),
    );
    return _handle(res);
  }
  // -------------------- CLOSE CHIT --------------------
  static Future<Map<String, dynamic>> closeChit(String chitGroupId) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/close'),
      headers: await _headers(),
    );
    return _handle(res);
  }

  // -------------------- AUCTION --------------------
  static Future<Map<String, dynamic>> openAuction({
    required String chitGroupId,
    required int monthNo,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/open/$chitGroupId'),
      headers: await _headers(),
      body: jsonEncode({
        "month_no": monthNo,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> closeAuction({
    required String auctionRoundId,
    required String winningMemberId,
    required int winningBidAmount,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/close/$auctionRoundId'),
      headers: await _headers(),
      body: jsonEncode({
        "winning_member_id": winningMemberId,
        "winning_bid_amount": winningBidAmount,
      }),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>?> getLiveAuction(String chitGroupId) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/live/$chitGroupId'),
      headers: await _headers(),
    );

    if (res.body == "null") return null;
    return _handle(res);
  }

  static Future<List<dynamic>> previewRules(
      String chitGroupId,
      Map<String, dynamic> settings,
      ) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/preview-rules'),
      headers: await _headers(),
      body: jsonEncode(settings),
    );

    final data = _handle(res);        // Map<String, dynamic>
    return List<dynamic>.from(data["preview"]);
  }

  static Future<void> transferSlot(
      String chitGroupId,
      String slotId,
      String name,
      String? mobile,
      ) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/slots/$slotId/transfer'),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "mobile_number": mobile,
      }),
    );

    _handle(res); // expect 200 OK, ignore body
  }

  static Future<void> deleteSlot(
      String chitGroupId,
      String slotId,
      ) async {
    final res = await http.delete(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/slots/$slotId'),
      headers: await _headers(),
    );

    _handle(res); // expect 200 OK
  }

  static Future<Map<String, dynamic>> createAndActivate(Map<String, dynamic> fullPayload) async {
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/quick-chit/create-active'),
        headers: await _headers(),
        body: jsonEncode(fullPayload),
      ).timeout(const Duration(seconds: 15)); // Add a timeout for better UX

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Safely parse the error detail
        String errorMessage = "Failed to create active chit";
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? errorMessage;
        } catch (_) {
          // Fallback if response body is not valid JSON
          errorMessage = "Server Error: ${response.statusCode}";
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Catch timeouts or network issues
      throw Exception(e.toString().contains('TimeoutException')
          ? "Connection timed out. Please try again."
          : e.toString());
    }
  }

  static Future<Map<String, dynamic>> previewCurve(Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/preview-curve'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return _handle(res); // returns Map<String, dynamic>
  }



}
