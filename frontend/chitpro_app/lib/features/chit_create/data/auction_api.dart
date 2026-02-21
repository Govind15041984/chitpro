import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';

class AuctionApi {

  static Future<Map<String, dynamic>?> getLiveAuction(String chitGroupId) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/auction-rounds/live/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200 && res.body != "null") {
      return jsonDecode(res.body);
    }
    return null;
  }

  static Future<Map<String, dynamic>> openAuction({
    required String chitGroupId,
    required int monthNo,
  }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/open/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "month_no": monthNo,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to open auction: ${res.body}");
    }

    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> closeAuction({
    required String auctionRoundId,
    required String winningMemberId,
    int? winningBidAmount, // null for Kulukal
  }) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/auction-rounds/close/$auctionRoundId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "winning_member_id": winningMemberId,
        "winning_bid_amount": winningBidAmount,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to close auction: ${res.body}");
    }

    return jsonDecode(res.body);
  }


  static Future<List<Map<String, dynamic>>> searchMembers(
      String chitGroupId,
      String query,
      ) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-members/$chitGroupId/search?q=$query'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to search members: ${res.body}");
    }

    final List data = jsonDecode(res.body);
    return data.cast<Map<String, dynamic>>();
  }


}
