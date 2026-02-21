import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/auth_storage.dart';
import '../../../api/config_api.dart'; // Assuming kBaseUrl is here

class SubscriptionApi {
  // --- 1. Get Razorpay Config (Public Key) ---
  static Future<Map<String, dynamic>> getPaymentConfig() async {
    final token = await AuthStorage.instance.getToken();
    final response = await http.get(
      Uri.parse('$kBaseUrl/subscription/config'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load payment configuration");
  }

  // --- 2. Create Razorpay Order on Backend ---
  static Future<Map<String, dynamic>> createOrder(String planCode) async {
    final token = await AuthStorage.instance.getToken();
    final response = await http.post(
      Uri.parse('$kBaseUrl/subscription/create-order'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"slab_code": planCode}),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Order creation failed: ${response.body}");
  }

  // --- 3. Verify Razorpay Signature (Secure Verification) ---
  static Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final token = await AuthStorage.instance.getToken();
    final response = await http.post(
      Uri.parse('$kBaseUrl/subscription/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "order_id": orderId,      // Match backend schema
        "razorpay_payment_id": paymentId,  // Match backend schema
        "razorpay_signature": signature,    // Match backend schema
      }),
    );
    return response.statusCode == 200;
  }

  // 2. NEW: Fetch available plans for the UI
  static Future<List<dynamic>> getPlans() async {
    final token = await AuthStorage.instance.getToken();
    final response = await http.get(
      Uri.parse('$kBaseUrl/subscription/plans'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to load plans");
  }

  // --- Keep your existing helper methods ---
  static Future<Map<String, dynamic>> getCurrent() async {
    final token = await AuthStorage.instance.getToken();
    final res = await http.get(
      Uri.parse('$kBaseUrl/subscription/current'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) throw Exception("Failed to load subscription");
    return jsonDecode(res.body);
  }
}