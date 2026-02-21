import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chitpro_app/features/chit_create/data/chit_create_api.dart';

class ChitRulesScreen extends StatefulWidget {
  final String chitGroupId;
  final String groupName;
  final int totalMonths;
  final int chitAmount;

  const ChitRulesScreen({
    super.key,
    required this.chitGroupId,
    required this.groupName,
    required this.totalMonths,
    required this.chitAmount,
  });

  @override
  State<ChitRulesScreen> createState() => _ChitRulesScreenState();
}

class _ChitRulesScreenState extends State<ChitRulesScreen> {
  bool isLoading = false;

  // --- CONFIGURATION VARIABLES ---
  String chitType = "KULUKAL";
  String monthlyDueType = "FIXED";
  int? monthlyDueAmount; // Left empty for Foreman input

  String prizeMode = "CURVE";
  int? firstPrize;
  int? lastPrize;
  int? flatPrizeAmount;

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

  final Color primaryGreen = const Color(0xFF004D40);
  final Color accentGold = const Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    // Screen is ready immediately because data is passed in constructor
  }

  void _syncRules() {
    setState(() {
      if (chitType == "KULUKAL") {
        // Requirement 2: Kulukal is always FIXED
        monthlyDueType = "FIXED";

        // Since it's FIXED, we allow carryForward to be user-toggled,
        // but your Requirement 2 says default it to 'false'
        // carryForward = false;

        if (prizeMode == "AUCTION") prizeMode = "CURVE";
      }
      else if (chitType == "AUCTION") {
        prizeMode = "AUCTION";
        // Auctions are usually VARIABLE
        monthlyDueType = "VARIABLE";
      }

      // --- APPLY YOUR NEW RULE ---
      // Rule: If Installment is variable, reserve pool is NOT carried forward
      if (monthlyDueType == "VARIABLE") {
        carryForward = false;
      }
    });
  }

  // --- CORE LOGIC: PREVIEW CALCULATION ---
  List<Map<String, dynamic>> _calculateLocalPreview() {
    List<Map<String, dynamic>> curve = [];
    int months = widget.totalMonths;
    int totalAmount = widget.chitAmount;

    if (prizeMode == "FLAT") {
      int flatVal = flatPrizeAmount ?? firstPrize ?? (totalAmount * 0.95).toInt();
      for (int m = 1; m <= months; m++) {
        curve.add({
          "month": m,
          "type": m == foremanMonth ? "FOREMAN" : "PRIZE",
          "payout": m == foremanMonth ? totalAmount : flatVal
        });
      }
      return curve;
    }

    int startVal = firstPrize ?? (totalAmount * 0.9).toInt();
    int endVal = lastPrize ?? totalAmount;

    List<int> bookletSteps = [1000, ...List.filled(8, 500), ...List.filled(3, 1000), 2500, 3000, 3500, 4000, 4000, 5000, 5000];
    while (bookletSteps.length < (months - 2)) { bookletSteps.add(5000); }

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
        curve.add({"month": m, "type": "FOREMAN", "payout": totalAmount});
      } else {
        curve.add({
          "month": m,
          "type": "PRIZE",
          "payout": (prizeIdx < prizeValues.length) ? prizeValues[prizeIdx] : endVal
        });
        prizeIdx++;
      }
    }
    return curve;
  }

  Future<void> _handleActivation() async {
    if (monthlyDueAmount == null || monthlyDueAmount == 0) {
      _showError("Please enter the Monthly Installment.");
      return;
    }

    setState(() => isLoading = true);
    try {
      // Mapping your mental model directly to the payload
      final payload = {
        "chit_type": chitType, // e.g., "AUCTION"

        "prize_rule": {
          "mode": prizeMode, // "AUCTION" or "CURVE"
          "first_prize": firstPrize ?? 0,
          "last_prize": lastPrize ?? 0,
          "curve_model": "BOOKLET_PIECEWISE",
        },

        "monthly_due": {
          // If Auction, type is VARIABLE. If Kulukal, it's FIXED.
          "type": (chitType == "AUCTION") ? "VARIABLE" : "FIXED",
          "amount": monthlyDueAmount,
        },

        "auction_rule": (chitType == "AUCTION") ? {
          "base_type": "MANUAL",
          "max_bid_pct": maxBidPct ?? 30,
          "min_bid_pct": minBidPct ?? 5,
          "auto_reduce_pct": null,
        } : null,

        "foreman_rule": {
          "type": foremanType,
          "month_no": foremanMonth,
          "percentage": foremanPct,
        },

        "reserve_rule": {
          "carry_forward": carryForward,
          "use_for_final_payout": useReserveForFinal,
          "allow_multiple_auction": allowMultipleAuction,
          "use_for_last_month_reduce": reduceLastMonth,
        },

        "dividend_rule": (chitType == "AUCTION") ? {
          "type": "DIVIDEND",
          "distribution": "VARIABLE",
          "fixed_amount": null,
        } : {
          "type": "NONE",
          "distribution": "NONE",
          "fixed_amount": null,
        },

        "schedule_rule": {
          "day": scheduleDay,
          "week": 1,
          "weekday": 1,
          "frequency": scheduleFrequency,
        },
        "preview": null,
      };

      await ChitCreateApi.configureChit(widget.chitGroupId, payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      String msg = e.toString().replaceAll("Exception:", "").trim();
      _showError(msg);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      appBar: AppBar(
        title: Text(widget.groupName.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 15),
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35))),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 120),
                children: [
                  _buildLockedInfoCard(),

                  _sectionTitle("Structure & Dues"),
                  _buildTypeToggle(),
                  _buildModernField("Monthly Installment", monthlyDueAmount, (v) => monthlyDueAmount = v, prefix: "₹"),

                  // --- 1. DIVIDEND SECTION (Added here) ---
                  if (chitType == "AUCTION") ...[
                    const SizedBox(height: 20),
                    _sectionTitle("Dividend Logic"),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                      child: Row(
                        children: [
                          _buildTabButton("DIVIDEND (VARIABLE)", monthlyDueType == "VARIABLE", () => setState(() => monthlyDueType = "VARIABLE")),
                          _buildTabButton("NONE (FIXED)", monthlyDueType == "FIXED", () => setState(() => monthlyDueType = "FIXED")),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                  _sectionTitle("Prize Distribution"),
                  _buildPrizeSelector(),

                  // ... (Keep your Prize Mode if/else logic here) ...
                  if (prizeMode == "CURVE") ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildModernField("First Prize", firstPrize, (v) => firstPrize = v, prefix: "₹")),
                        const SizedBox(width: 15),
                        Expanded(child: _buildModernField("Last Prize", lastPrize, (v) => lastPrize = v, prefix: "₹")),
                      ],
                    ),
                  ] else if (prizeMode == "FLAT") ...[
                    const SizedBox(height: 16),
                    _buildModernField("Fixed Prize Amount", flatPrizeAmount, (v) => flatPrizeAmount = v, prefix: "₹"),
                  ],

                  if (chitType == "KULUKAL")
                    TextButton.icon(
                      onPressed: () => _showPreviewModal(_calculateLocalPreview()),
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: Text("PREVIEW ${widget.totalMonths} MONTHS CURVE", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 30),
                  _sectionTitle("Management"),
                  _buildForemanSlider(),
                  const SizedBox(height: 16),
                  _buildModernField("Standard Auction Day", scheduleDay, (v) => scheduleDay = v, suffix: "th of Month"),

                  const SizedBox(height: 30),
                  _sectionTitle("Reserve Settings"),
                  // --- 2. RESTORING MISSING RESERVE TILES ---
                  _buildReserveTile("Pool Carry Forward", carryForward, (v) => setState(() => carryForward = v)),
                  _buildReserveTile("Allow Multiple Auctions", allowMultipleAuction, (v) => setState(() => allowMultipleAuction = v)),
                  _buildReserveTile("Reduce Last Month Due", reduceLastMonth, (v) => setState(() => reduceLastMonth = v)),
                  _buildReserveTile("Use for Final Payout", useReserveForFinal, (v) => setState(() => useReserveForFinal = v)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildActivateButton(),
    );
  }

  Widget _buildLockedInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(color: primaryGreen.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryGreen.withOpacity(0.1))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _lockedStat("CHIT VALUE", "₹${widget.chitAmount}"),
        Container(width: 1, height: 30, color: Colors.grey[300]),
        _lockedStat("DURATION", "${widget.totalMonths} Months"),
      ]),
    );
  }

  Widget _lockedStat(String label, String value) => Column(children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(value, style: TextStyle(fontSize: 16, color: primaryGreen, fontWeight: FontWeight.w900))]);

  Widget _buildForemanSlider() => Container(
    padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Foreman Payout Month", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text("Month $foremanMonth", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w900, fontSize: 16))]),
      Slider(value: foremanMonth.toDouble(), min: 1, max: widget.totalMonths.toDouble(), activeColor: primaryGreen, onChanged: (v) => setState(() => foremanMonth = v.toInt())),
    ]),
  );

  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text.toUpperCase(), style: TextStyle(color: primaryGreen.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)));
  Widget _buildTypeToggle() => Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)), child: Row(children: ["KULUKAL", "AUCTION"].map((t) => Expanded(child: GestureDetector(onTap: () => setState(() { chitType = t; _syncRules(); }), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: chitType == t ? primaryGreen : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(t, style: TextStyle(color: chitType == t ? Colors.white : Colors.black54, fontWeight: FontWeight.bold))))))).toList()));
  Widget _buildMonthlyDueLogic() {
    // Only show this if AUCTION is selected
    if (chitType != "AUCTION") return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _sectionTitle("Monthly Due Strategy"),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
          child: Row(
            children: ["FIXED", "DIVIDEND"].map((t) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => monthlyDueType = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                      color: monthlyDueType == t ? primaryGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Center(
                    child: Text(t, style: TextStyle(
                        color: monthlyDueType == t ? Colors.white : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                    )),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            monthlyDueType == "DIVIDEND"
                ? "Profit from auction is shared. Members pay less than the installment."
                : "Fixed installment. Auction profit is handled separately.",
            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
  Widget _buildModernField(String l, int? v, Function(int) onU, {String? prefix, String? suffix}) => Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Row(children: [if (prefix != null) Text(prefix, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Expanded(child: TextFormField(initialValue: v?.toString() ?? "", keyboardType: TextInputType.number, onChanged: (val) => onU(int.tryParse(val) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), decoration: const InputDecoration(border: InputBorder.none, isDense: true))), if (suffix != null) Text(suffix, style: const TextStyle(color: Colors.grey, fontSize: 12))])]));
  Widget _buildPrizeSelector() => Wrap(spacing: 10, children: (chitType == "AUCTION" ? ["AUCTION"] : ["CURVE", "FLAT"]).map((m) => ChoiceChip(label: Text(m), selected: prizeMode == m, selectedColor: primaryGreen, labelStyle: TextStyle(color: prizeMode == m ? Colors.white : Colors.black), onSelected: (_) => setState(() => prizeMode = m))).toList());
  Widget _buildReserveTile(String t, bool v, Function(bool) o) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)), child: SwitchListTile(title: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), value: v, onChanged: o, activeColor: primaryGreen));
  Widget _buildActivateButton() => SizedBox(width: MediaQuery.of(context).size.width * 0.9, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 8), onPressed: isLoading ? null : _handleActivation, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRM & ACTIVATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2))));
  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  void _showPreviewModal(List<Map<String, dynamic>> data) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (_) => Container(height: MediaQuery.of(context).size.height * 0.75, padding: const EdgeInsets.all(24), child: Column(children: [const Text("STRICT BOOKLET PREVIEW", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const Divider(), Expanded(child: ListView.builder(itemCount: data.length, itemBuilder: (_, i) => ListTile(leading: CircleAvatar(backgroundColor: data[i]['type'] == "FOREMAN" ? accentGold : primaryGreen.withOpacity(0.1), child: Text("${data[i]['month']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))), title: Text(data[i]['type']), trailing: Text("₹${data[i]['payout']}", style: const TextStyle(fontWeight: FontWeight.bold)))))])));
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: isSelected ? primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10)
        ),
        child: Center(
          child: Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
              fontSize: 10
          )),
        ),
      ),
    ),
  );
}