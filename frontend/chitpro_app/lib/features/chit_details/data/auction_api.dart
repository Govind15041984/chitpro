import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';

class AuctionApi {
  // -----------------------------------------
  // Get LIVE auction round (FULL OBJECT)
  // -----------------------------------------
  static Future<Map<String, dynamic>?> getLiveAuction(
      String chitGroupId,
      ) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/live/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 || res.body == 'null') {
      return null;
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // -----------------------------------------
  // Open auction round (BACKEND decides month)
  // ✅ UPDATED: return FULL auction object
  // -----------------------------------------
  static Future<Map<String, dynamic>> openAuctionRound({
    required String chitGroupId,
  }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/open/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = jsonDecode(res.body);
      final msg = body["detail"] ?? "Something went wrong. Please check your settings.";
      throw Exception(res.body); // 👈 log real backend error
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data; // ✅ return full auction JSON
  }

  // -----------------------------------------
  // Eligible members
  // -----------------------------------------
  static Future<List<Map<String, dynamic>>> getEligibleMembers(
      String chitGroupId,
      int monthNo,
      String query,
      ) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse(
        '$kBaseUrl/chit-members/$chitGroupId/search'
            '?q=$query&month_no=$monthNo',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }


  // -----------------------------------------
  // Confirm auction winner (FIXED)
  // -----------------------------------------
  static Future<void> closeAuctionRound({
    required String auctionRoundId,
    required String winningMemberId,
    int? winningBidAmount,
  }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/close/$auctionRoundId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'winning_member_id': winningMemberId,
        'winning_bid_amount': winningBidAmount,
      }),
    );

    // 🔥 IMPORTANT: Do NOT jsonDecode on non-200
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(res.body);  // show backend error clearly
    }

    if (res.body.isNotEmpty) {
      jsonDecode(res.body); // only decode if success JSON
    }
  }


  // -----------------------------------------
  // Close month
  // -----------------------------------------
  static Future<void> closeMonth(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-groups/$chitGroupId/close-month'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      //throw Exception(res.body);
      final body = jsonDecode(res.body);
      final msg = body["detail"] ?? "Something went wrong. Please check your settings.";
      throw Exception(msg);
    }
  }

  static Future<Map<String, dynamic>?> getLatestAuction(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/latest/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 || res.body == 'null') {
      return null;
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPrizePreview({
    required String chitGroupId,
    required int monthNo,
    }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/preview-prize/$chitGroupId/$monthNo'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(res.body);
    }

    return jsonDecode(res.body);
  }

  static Future<List<Map<String, dynamic>>> getMonthRounds({
    required String chitGroupId,
    required int monthNo,
  }) async {
     final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/month/$chitGroupId/$monthNo'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body["detail"] ?? "Failed to load auction rounds");
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data);
  }


}
