import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/chit_create_provider.dart';

class ChitRuleSettingsScreen extends ConsumerStatefulWidget {
  const ChitRuleSettingsScreen({super.key});

  @override
  ConsumerState<ChitRuleSettingsScreen> createState() => _ChitRuleSettingsScreenState();
}

class _ChitRuleSettingsScreenState extends ConsumerState<ChitRuleSettingsScreen> {
  // ---------------------------------------------------------------------------
  // 1. FORM STATE
  // ---------------------------------------------------------------------------
  String chitType = "KULUKAL";
  String monthlyDueType = "FIXED";
  int? monthlyDueAmount;

  String prizeMode = "CURVE";
  int? firstPrize;
  int? lastPrize;

  String foremanType = "FULL_MONTH";
  int foremanMonth = 1;
  int? foremanPct = 5;

  bool carryForward = true;
  bool allowMultipleAuction = false;
  bool reduceLastMonth = false;
  bool useReserveForFinal = false;

  int? minBidPct = 5;
  int? maxBidPct = 30;

  String scheduleFrequency = "MONTHLY_DATE";
  int scheduleDay = 15;

  // ---------------------------------------------------------------------------
  // 2. CORE LOGIC: STRICT PIECEWISE SCALING
  // ---------------------------------------------------------------------------

  void _syncRules() {
    setState(() {
      if (chitType == "KULUKAL") {
        monthlyDueType = "FIXED"; // Kulukal is almost always Fixed
        if (prizeMode == "AUCTION") prizeMode = "CURVE";
      } else if (chitType == "AUCTION") {
        prizeMode = "AUCTION";
        // Only force Variable if it's an Auction and Carry Forward is off
        //if (!carryForward) monthlyDueType = "VARIABLE";
      }
    });
  }

  List<Map<String, dynamic>> _calculateLocalPreview(int months, int chitAmount) {
    List<Map<String, dynamic>> curve = [];

    // --- FLAT MODE LOGIC ---
    if (prizeMode == "FLAT") {
      int flatVal = firstPrize ?? chitAmount;
      for (int m = 1; m <= months; m++) {
        if (m == foremanMonth) {
          curve.add({"month": m, "type": "FOREMAN", "payout": chitAmount});
        } else {
          curve.add({"month": m, "type": "PRIZE", "payout": flatVal});
        }
      }
      return curve;
    }

    // --- CURVE MODE LOGIC (Strict Booklet Scaling) ---
    int startVal = firstPrize ?? (chitAmount * 0.9).toInt();
    int endVal = lastPrize ?? chitAmount;

    List<int> bookletSteps = [
      1000, ...List.filled(8, 500), ...List.filled(3, 1000),
      2500, 3000, 3500, 4000, 4000, 5000, 5000
    ];

    while (bookletSteps.length < (months - 2)) {
      bookletSteps.add(5000);
    }

    final neededJumps = months - 2;
    List<int> activeSteps = bookletSteps.sublist(0, neededJumps);

    int sumOfSteps = activeSteps.isEmpty ? 1 : activeSteps.fold(0, (a, b) => a + b);
    double factor = (endVal - startVal) / sumOfSteps;

    List<int> prizeValues = [startVal];
    double currentAccumulator = startVal.toDouble();

    for (var step in activeSteps) {
      currentAccumulator += (step * factor);
      prizeValues.add(currentAccumulator.round());
    }

    int prizeIdx = 0;
    for (int m = 1; m <= months; m++) {
      if (m == foremanMonth) {
        curve.add({"month": m, "type": "FOREMAN", "payout": chitAmount});
      } else {
        int val = (prizeIdx < prizeValues.length) ? prizeValues[prizeIdx] : endVal;
        curve.add({"month": m, "type": "PRIZE", "payout": val});
        prizeIdx++;
      }
    }
    return curve;
  }

  // ---------------------------------------------------------------------------
  // 3. UI AND ACTIONS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildSettingsPayload() {
    // Ensure we never send null prizes. Fallback to 0 or total amount.
    int p1 = firstPrize ?? 0;
    int p2 = (prizeMode == "CURVE") ? (lastPrize ?? 0) : (firstPrize ?? 0);

    return {
      "preview": null,
      "chit_type": chitType,
      "prize_rule": {
        "mode": prizeMode,
        "first_prize": p1,
        "last_prize": p2,
        "curve_model": prizeMode == "CURVE" ? "BOOKLET_PIECEWISE" : "FLAT",
      },
      "monthly_due": {
        "type": (chitType == "AUCTION") ? monthlyDueType : "FIXED",
        "amount": monthlyDueAmount ?? 0,
      },
      "auction_rule": (chitType == "AUCTION") ? {
        "min_bid_pct": minBidPct ?? 5,
        "max_bid_pct": maxBidPct ?? 30,
        "base_type": "MANUAL",
        "auto_reduce_pct": null, // Added to match your sample exactly
      } : null,
      "dividend_rule": (chitType == "AUCTION" && monthlyDueType == "VARIABLE") ? {
        "type": "DIVIDEND",
        "distribution": "VARIABLE",
        "fixed_amount": null,
      } : {
        "type": "NONE",
        "distribution": "NONE",
        "fixed_amount": null,
      },
      "foreman_rule": {
        "type": foremanType,
        "month_no": foremanMonth,
        "percentage": foremanPct ?? 5,
      },
      "reserve_rule": {
        "carry_forward": carryForward,
        "allow_multiple_auction": allowMultipleAuction,
        "use_for_last_month_reduce": reduceLastMonth,
        "use_for_final_payout": useReserveForFinal,
      },
      "schedule_rule": {
        "frequency": scheduleFrequency,
        "day": scheduleDay,
        "week": 1,
        "weekday": 1,
      },
    };
  }

  void _showSuccessOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF004D40), size: 80),
                SizedBox(height: 16),
                Text("Chit Activated!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPreviewModal(List<Map<String, dynamic>> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Strict Booklet Preview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(child: Text("${data[i]['month']}")),
                title: Text(data[i]['type']),
                trailing: Text("₹${data[i]['payout']}"),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(chitCreateProvider);
    final int currentDuration = controller.draft.totalMonths;
    final int currentTotalAmount = controller.draft.chitAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text("Rule Configuration"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _section("System", [
              _choiceRow("Chit Type", chitType, ["KULUKAL", "AUCTION"], (v) {
                setState(() {
                  chitType = v;
                  _syncRules();
                });
              }),

              _choiceRow(
                  "Monthly Due",
                  monthlyDueType,
                  ["FIXED", "VARIABLE"],
                  // Only lock to FIXED if it is KULUKAL.
                  // Carry Forward should NOT lock this choice.
                  (chitType == "KULUKAL") ? null : (v) => setState(() => monthlyDueType = v)
              ),

              // This field will now appear/disappear based on your manual selection
              if (monthlyDueType == "FIXED")
                _numberField(
                    "Monthly Amount (₹)",
                    monthlyDueAmount,
                        (v) => setState(() => monthlyDueAmount = v)
                ),
            ]),

            _section("Prize Schedule", [
              _choiceRow("Prize Mode", prizeMode, chitType == "AUCTION" ? ["AUCTION"] : ["CURVE", "FLAT"], (v) => setState(() => prizeMode = v)),

              if (prizeMode == "FLAT") _numberField("Flat Prize Value (₹)", firstPrize, (v) => setState(() => firstPrize = v)),

              if (prizeMode == "CURVE") ...[
                _numberField("Starting Prize (₹)", firstPrize, (v) => setState(() => firstPrize = v)),
                _numberField("Last Month Prize (₹)", lastPrize, (v) => setState(() => lastPrize = v)),
              ],

              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: Text("PREVIEW $currentDuration MONTHS"),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    foregroundColor: const Color(0xFF004D40),
                    side: const BorderSide(color: Color(0xFF004D40))
                ),
                onPressed: () {
                  final data = _calculateLocalPreview(currentDuration, currentTotalAmount);
                  _showPreviewModal(data);
                },
              ),
            ]),

            _section("Foreman & Reserve", [
              _choiceRow("Foreman Type", foremanType, ["FULL_MONTH", "PERCENTAGE"], (v) => setState(() => foremanType = v)),
              if (foremanType == "FULL_MONTH") _numberField("Foreman Payout Month", foremanMonth, (v) => setState(() => foremanMonth = v)),
              const Divider(height: 32),
              _switch("Carry Forward Reserve Pool", carryForward, (v) {
                setState(() {
                  carryForward = v;
                  // If user turns off Carry Forward in an AUCTION,
                  // it's safer to default to VARIABLE, but let them change it.
                  if (!v && chitType == "AUCTION") {
                    monthlyDueType = "VARIABLE";
                  }
                });
              }),
              _switch("Allow Multiple Auctions", allowMultipleAuction, (v) => setState(() => allowMultipleAuction = v)),
              _switch("Reduce Last Month Payment", reduceLastMonth, (v) => setState(() => reduceLastMonth = v)),
              _switch("Use Reserve for Final Payout", useReserveForFinal, (v) => setState(() => useReserveForFinal = v)),
            ]),
            _section("Schedule Settings", [
              _choiceRow("Frequency", scheduleFrequency, ["MONTHLY_DATE", "MONTHLY_DAY"],
                      (v) => setState(() => scheduleFrequency = v)),

              if (scheduleFrequency == "MONTHLY_DATE")
                _numberField("Day of Month (1-28)", scheduleDay,
                        (v) => setState(() => scheduleDay = v)),

              if (scheduleFrequency == "MONTHLY_DAY")
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text("Logic: Same day every month (e.g., 2nd Sunday)",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: controller.isLoading ? null : () async {
                  try {
                    final payload = _buildSettingsPayload();

                    // 1. PRETTY PRINT PAYLOAD TO CONSOLE
                    JsonEncoder encoder = const JsonEncoder.withIndent('  ');
                    debugPrint("🚀 SENDING PAYLOAD:\n${encoder.convert(payload)}");

                    await controller.configureRules(payload);

                    if (mounted) {
                      _showSuccessOverlay(context);
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  } catch (e) {
                    // 2. EXTRACT DETAILED ERROR FROM EXCEPTION
                    String detailedError = e.toString();

                    // If your controller throws an exception containing the response body
                    debugPrint("❌ ACTIVATION FAILED: $detailedError");

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $detailedError"),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 10), // Longer to read the detail
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: controller.isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("ACTIVATE GROUP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE UI HELPERS ---
  Widget _section(String title, List<Widget> children) => Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const Divider(height: 24), ...children]));
  Widget _choiceRow(String label, String current, List<String> options, Function(String)? onSelect) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 8), Wrap(spacing: 8, children: options.map((opt) => ChoiceChip(label: Text(opt), selected: current == opt, onSelected: onSelect == null ? null : (_) => onSelect(opt), selectedColor: const Color(0xFF004D40), labelStyle: TextStyle(color: current == opt ? Colors.white : Colors.black87))).toList()), const SizedBox(height: 16)]);
  Widget _switch(String label, bool value, Function(bool) onChanged) => SwitchListTile(title: Text(label, style: const TextStyle(fontSize: 14)), value: value, activeColor: const Color(0xFF004D40), contentPadding: EdgeInsets.zero, onChanged: onChanged);
  Widget _numberField(String label, int? value, Function(int) onChanged) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(initialValue: value?.toString() ?? "", keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onChanged: (v) { if (v.isNotEmpty) onChanged(int.parse(v)); }));
}