import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../data/subscription_api.dart';

class RazorpayHandler {
  late Razorpay _razorpay;

  // Callbacks to update the UI
  final Function(String) onSuccess;
  final Function(String) onFailure;

  RazorpayHandler({required this.onSuccess, required this.onFailure}) {
    _razorpay = Razorpay();

    // Attach Event Listeners
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // 1. Start the Subscription Flow
  Future<void> initPayment(String planCode) async {
    try {
      // Fire both requests simultaneously
      final results = await Future.wait([
        SubscriptionApi.getPaymentConfig(),
        SubscriptionApi.createOrder(planCode),
      ]);

      final config = results[0];
      final orderData = results[1];

      var options = {
        'key': config['key_id'],
        'amount': orderData['amount_paise'],
        'name': 'ChitPro Premium',
        'order_id': orderData['order_id'],
        'description': 'Payment for $planCode Plan',
        'prefill': {
          'contact': config['user_contact'] ?? '',
          'email': config['user_email'] ?? ''
        },
        'timeout': 300,
      };

      _razorpay.open(options);
    } catch (e) {
      onFailure("Payment Setup Failed: ${e.toString()}");
    }
  }

  // 2. Handle Success (Server-side Verification is Mandatory)
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Step D: Send signature to backend to verify authenticity
      bool isVerified = await SubscriptionApi.verifyPayment(
        orderId: response.orderId!,
        paymentId: response.paymentId!,
        signature: response.signature!,
      );

      if (isVerified) {
        onSuccess("Plan Activated Successfully!");
      } else {
        onFailure("Security Verification Failed. Contact Support.");
      }
    } catch (e) {
      onFailure("Verification Error: ${e.toString()}");
    }
  }

  // 3. Handle Failure
  void _handlePaymentError(PaymentFailureResponse response) {
    // response.code gives specific error types (cancelled, network, etc.)
    onFailure("Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onFailure("External Wallet ${response.walletName} selected. Please use internal methods.");
  }

  // Always clear listeners to avoid memory leaks
  void dispose() {
    _razorpay.clear();
  }
}