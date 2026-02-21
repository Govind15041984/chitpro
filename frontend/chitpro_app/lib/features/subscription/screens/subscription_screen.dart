import 'package:flutter/material.dart';
import '../logic/razorpay_handler.dart';
import '../data/subscription_api.dart';
import '../widgets/plan_card.dart';
import '../widgets/plan_activation_overlay.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late RazorpayHandler _paymentHandler;
  final PageController _pageController = PageController(viewportFraction: 0.82);

  List<dynamic> _plans = [];
  int _currentPage = 0;
  bool _isLoading = true;
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();

    // Initialize the handler with UI callbacks
    _paymentHandler = RazorpayHandler(
      onSuccess: (msg) {
        setState(() => _isActivating = true);
      },
      onFailure: (err) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
        );
      },
    );
  }

  // Fetch plans from your FastAPI backend
  Future<void> _loadPlans() async {
    try {
      final data = await SubscriptionApi.getPlans();
      setState(() {
        _plans = data;
        // Auto-focus the first paid plan (usually BASIC) if it exists
        final basicIndex = _plans.indexWhere((p) => p['slab_code'].toString().contains('BASIC'));
        _currentPage = basicIndex != -1 ? basicIndex : 0;
        _isLoading = false;
      });

      if (_plans.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentPage);
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sync Error: $e")),
      );
    }
  }

  // Logic based on your provided Feature Table
  List<String> _getDynamicFeatures(Map<String, dynamic> plan) {
    final String code = plan['slab_code'].toString().toUpperCase();

    // 1. Handle Limits dynamically from DB
    final String gLimit = (plan['max_groups'] ?? 0) >= 100
        ? "Unlimited Groups"
        : "${plan['max_groups']} Groups";

    final String mLimit = (plan['member_limit'] ?? 0) >= 500
        ? "Unlimited Members"
        : "${plan['member_limit']} Members";

    // 2. Map the "Power Features" based on the tier
    // These should ideally come from the DB as well, but here is the logical mapping:
    List<String> tierFeatures = [];

    if (code.contains('FREE')) {
      tierFeatures = [gLimit, mLimit, "Manual WhatsApp", "View Only Reports", "Email Support"];
    } else if (code.contains('BASIC')) {
      tierFeatures = [gLimit, mLimit, "WhatsApp + SMS Intent", "PDF Export Reports", "Email Support"];
    } else if (code.contains('STANDARD')) {
      tierFeatures = [gLimit, "Unlimited Members", "Auto Bulk SMS", "Excel + PDF Reports", "Automatic Late Fees", "Chat Support"];
    } else if (code.contains('PREMIUM') || code.contains('ULTIMATE')) {
      tierFeatures = ["Unlimited Groups", "Unlimited Members", "Priority WhatsApp API", "Custom Branding", "Dedicated Call Support"];
    } else {
      tierFeatures = [gLimit, mLimit, "Standard Business Tools"];
    }

    return tierFeatures;
  }

  // Dynamic Theme Colors for each Tier
  Color _getThemeColor(String code) {
    if (code.contains('FREE')) return Colors.blueGrey;
    if (code.contains('BASIC')) return const Color(0xFF004D40); // Teal
    if (code.contains('STANDARD')) return const Color(0xFF1565C0); // Blue
    return const Color(0xFFC5A059); // Gold
  }

  @override
  void dispose() {
    _pageController.dispose();
    _paymentHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show the "Welcome to the Club" animation after successful verification
    if (_isActivating) {
      return PlanActivationOverlay(
        onCompleted: () => Navigator.pop(context, true),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Plans & Pricing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : Column(
        children: [
          const SizedBox(height: 24),
          const Text("Select Your Business Scale",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text("Everything syncs with your Dashboard",
              style: TextStyle(color: Colors.blueGrey, fontSize: 14)),

          // The Snapping Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _plans.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                final code = plan['slab_code'].toString();

                return AnimatedScale(
                  scale: _currentPage == index ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 300),
                  child: PlanCard(
                    title: code.replaceAll('_', ' '),
                    price: "₹${plan['amount_per_month']}",
                    subtitle: code == 'FREE' ? "Current Plan" : "Upgrade to unlock",
                    features: _getDynamicFeatures(plan),
                    isSelected: _currentPage == index,
                    themeColor: _getThemeColor(code),
                    isPopular: code.contains('STANDARD'),
                  ),
                );
              },
            ),
          ),

          // The Action Button
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getThemeColor(_plans[_currentPage]['slab_code']),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: () {
                  final selectedPlan = _plans[_currentPage];
                  if (selectedPlan['slab_code'] == 'FREE') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("You are already on the Free Plan")),
                    );
                  } else {
                    // Triggers the Backend Order Creation + Razorpay UI
                    _paymentHandler.initPayment(selectedPlan['slab_code']);
                  }
                },
                child: Text(
                  _currentPage == 0 ? "CURRENT PLAN" : "ACTIVATE ${_plans[_currentPage]['slab_code'].toString().replaceAll('_', ' ')}",
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}