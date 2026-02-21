import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/chit_create_api.dart';

class CreateNewChitScreen extends StatefulWidget {
  const CreateNewChitScreen({super.key});

  @override
  State<CreateNewChitScreen> createState() => _CreateNewChitScreenState();
}

class _CreateNewChitScreenState extends State<CreateNewChitScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLLERS ---
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _slotsCtrl = TextEditingController();
  final _installmentCtrl = TextEditingController();
  final _scheduleValCtrl = TextEditingController(text: "15");
  final _firstPrizeCtrl = TextEditingController();
  final _lastPrizeCtrl = TextEditingController();

  // --- STATE VARIABLES ---
  bool isLoading = false;
  String chitType = "KULUKAL";
  String monthlyDueType = "FIXED";
  String prizeMode = "CURVE";

  String foremanType = "FULL_MONTH";
  String foremanMonthType = "Any";
  int foremanMonth = 1;
  int foremanPct = 5;

  bool carryForward = true;
  bool allowMultipleAuction = false;
  bool useForFinalPayout = false;
  bool useForLastMonthReduce = false;

  String scheduleFrequency = "MONTHLY_DATE";
  int scheduleValue = 15;

  final Color primaryGreen = const Color(0xFF004D40);
  final Color backgroundColor = const Color(0xFFF1F5F9);

  // --- LOGIC: REACTIVE SYNC ---
  void _onChitTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      chitType = type;
      if (chitType == "AUCTION") {
        monthlyDueType = "VARIABLE";
        prizeMode = "AUCTION";
        carryForward = false;
      } else {
        monthlyDueType = "FIXED";
        prizeMode = "CURVE";
        carryForward = true;
      }
    });
  }



  Future<void> _showPreviewModal() async {
    if (_amountCtrl.text.isEmpty || _monthsCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter chit amount and duration first")),
      );
      return;
    }

    try {
      final res = await ChitCreateApi.previewCurve({
        "chit_amount": int.parse(_amountCtrl.text),
        "duration_months": int.parse(_monthsCtrl.text),
        "chit_type": chitType,
        "prize_mode": prizeMode,
        "foreman_type": foremanType,        // "FULL_MONTH"
        "foreman_month": foremanMonth,
      });

      final List<dynamic> curve = res["preview"];

      if (curve.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No payout preview available for this configuration")),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Prize Distribution Preview",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: curve.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = curve[i];
                    final isForeman = item['type'] == "FOREMAN";

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isForeman ? Colors.amber.withOpacity(0.15) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isForeman ? Colors.amber : Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // Month badge
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isForeman ? Colors.amber : primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${item['month']}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Type + label
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isForeman ? "Foreman Payout" : "Member Prize",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isForeman ? Colors.orange.shade800 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isForeman ? "Full chit amount" : "As per curve",
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                ),
                              ],
                            ),
                          ),

                          // Amount
                          Text(
                            "₹${item['payout']}",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isForeman ? Colors.orange.shade900 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load preview: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- API INTEGRATION ---
  Future<void> _handleCreateAndActivate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final payload = {
        "group_name": _nameCtrl.text,
        "chit_amount": int.parse(_amountCtrl.text),
        "total_slots": int.parse(_slotsCtrl.text),
        "duration_months": int.parse(_monthsCtrl.text),
        "rules": {
          "chit_type": chitType,
          "monthly_due_type": monthlyDueType,
          "installment_amount": int.parse(_installmentCtrl.text),
          "prize_mode": (chitType == "AUCTION") ? "AUCTION" : prizeMode,
          "first_prize": int.tryParse(_firstPrizeCtrl.text) ?? 0,
          "last_prize": prizeMode == "CURVE" ? (int.tryParse(_lastPrizeCtrl.text) ?? 0) : (int.tryParse(_firstPrizeCtrl.text) ?? 0),
          "foreman_type": foremanType,
          "foreman_val": (foremanType == "FULL_MONTH") ? (foremanMonthType == "Any" ? 0 : foremanMonth) : foremanPct,
          "carry_forward": (chitType == "AUCTION") ? false : carryForward,
          "allow_multiple_auction": allowMultipleAuction,
          "use_for_final_payout": useForFinalPayout,
          "use_for_last_month_reduce": useForLastMonthReduce,
          "frequency": scheduleFrequency,
          "schedule_val": scheduleValue,
        }
      };

      await ChitCreateApi.createAndActivate(payload);
      if (mounted) _showSuccessSheet();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: const Text("Create Active Chit", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: primaryGreen, foregroundColor: Colors.white, elevation: 0),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildCard("BASIC DETAILS", [
              _inputField("Chit Group Name", _nameCtrl, Icons.edit_note),
              const SizedBox(height: 15),
              Row(children: [
                Expanded(
                  child: _inputField(
                    "Total Amount",
                    _amountCtrl,
                    Icons.currency_rupee,
                    isNum: true,
                    onChanged: (_) => setState(_recalculateCurvePreview),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _inputField(
                    "Duration (Mo)",
                    _monthsCtrl,
                    Icons.timer_outlined,
                    isNum: true,
                    onChanged: (_) => setState(_recalculateCurvePreview),
                  ),
                ),
              ]),
              const SizedBox(height: 15),
              _inputField("Total Slots / Members", _slotsCtrl, Icons.groups_outlined, isNum: true),
            ]),

            _buildCard("AUCTION STRUCTURE", [
              _sectionTitle("Chit Type"),
              _buildTypeToggle(),
              const SizedBox(height: 20),
              _sectionTitle("Monthly Due Type"),
              Row(
                children: [
                  _buildTogglePill(
                    "FIXED",
                    monthlyDueType == "FIXED",
                        () => setState(() => monthlyDueType = "FIXED"),
                  ),
                  const SizedBox(width: 10),
                  _buildTogglePill(
                    "VARIABLE",
                    monthlyDueType == "VARIABLE",
                        () => setState(() {
                      monthlyDueType = "VARIABLE";
                      carryForward = false;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _inputField("Standard Installment Amount", _installmentCtrl, Icons.payments_outlined, isNum: true),
              if (chitType == "KULUKAL") ...[
                const SizedBox(height: 20),
                _sectionTitle("Prize Mode"),
                _buildPrizeToggle(),
                const SizedBox(height: 15),
                if (prizeMode == "FLAT") _inputField("Flat Prize Value (₹)", _firstPrizeCtrl, Icons.star, isNum: true),
                if (prizeMode == "CURVE") ...[
                  if (_amountCtrl.text.isEmpty || _monthsCtrl.text.isEmpty)
                    const Text(
                      "Enter chit amount and duration to preview curve values.",
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    )
                  else ...[
                    TextFormField(
                      controller: _firstPrizeCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Starting Prize (₹)",
                        prefixIcon: Icon(Icons.trending_up, size: 20, color: primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _lastPrizeCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Last Month Prize (₹)",
                        prefixIcon: Icon(Icons.flag, size: 20, color: primaryGreen),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 15),
              ],
            ]),

            _buildCard("FOREMAN COMMISSION", [
              _sectionTitle("Foreman Payout Type"),
              Row(
                children: [
                  _buildTogglePill(
                    "FULL MONTH",
                    foremanType == "FULL_MONTH",
                        () => setState(() => foremanType = "FULL_MONTH"),
                  ),
                  const SizedBox(width: 10),
                  _buildTogglePill(
                    "PERCENTAGE",
                    foremanType == "PERCENTAGE",
                        () => setState(() => foremanType = "PERCENTAGE"),
                  ),
                ],
              ),
              if (foremanType == "FULL_MONTH") ...[
                const SizedBox(height: 15),
                _sectionTitle("Month Option"),
                Row(
                  children: [
                    _buildTogglePill(
                      "ANY MONTH",
                      foremanMonthType == "Any",
                          () => setState(() => foremanMonthType = "Any"),
                    ),
                    const SizedBox(width: 10),
                    _buildTogglePill(
                      "SPECIFIC MONTH",
                      foremanMonthType == "Specific",
                          () => setState(() => foremanMonthType = "Specific"),
                    ),
                  ],
                ),
                if (foremanMonthType == "Specific") ...[
                  const SizedBox(height: 10),
                  Text("Payout Month: $foremanMonth", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                  _inputField(
                    "Foreman Payout Month (1 - ${_monthsCtrl.text.isEmpty ? '?' : _monthsCtrl.text})",
                    null,
                    Icons.event_available,
                    isNum: true,
                    onChanged: (v) {
                      final entered = int.tryParse(v) ?? 0;
                      final maxMonths = int.tryParse(_monthsCtrl.text) ?? 0;

                      setState(() {
                        if (entered < 1) {
                          foremanMonth = 1;
                        } else if (maxMonths > 0 && entered > maxMonths) {
                          foremanMonth = maxMonths;
                        } else {
                          foremanMonth = entered;
                        }
                      });
                    },
                  ),
                ]
              ] else ...[
                const SizedBox(height: 15),
                _inputField("Commission Percentage (%)", null, Icons.percent, isNum: true, onChanged: (v) => foremanPct = int.tryParse(v) ?? 5),
              ],
            ]),

            _buildCard("PAYOUT PREVIEW", [
              const Text(
                "Preview full payout schedule including Foreman month impact.",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),

              if (chitType == "KULUKAL" && prizeMode == "CURVE") ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text("VIEW PAYOUT SCHEDULE"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: primaryGreen,
                    side: BorderSide(color: primaryGreen),
                  ),
                  onPressed: _showPreviewModal,
                ),
              ] else ...[
                const Text(
                  "Preview is available only for Curve-based chits.",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ]
            ]),

            _buildCard("RESERVE POOL SETTINGS", [
              _buildSwitchTile("Carry Forward Pool", carryForward, (chitType == "AUCTION" || monthlyDueType == "VARIABLE") ? null : (v) => setState(()=> carryForward = v), subtitle: (chitType == "AUCTION" || monthlyDueType == "VARIABLE") ? "Disabled for Variable/Auction chits" : "Roll over unused reserve"),
              _buildSwitchTile("Allow Multiple Auctions", allowMultipleAuction, (v) => setState(()=> allowMultipleAuction = v)),
              _buildSwitchTile("Use for Final Payout", useForFinalPayout, (v) => setState(()=> useForFinalPayout = v)),
              _buildSwitchTile("Reduce Last Month Due", useForLastMonthReduce, (v) => setState(()=> useForLastMonthReduce = v)),
            ]),

            _buildCard("SCHEDULE", [
              Row(
                children: [
                  _buildTogglePill(
                    "MONTHLY",
                    scheduleFrequency == "MONTHLY_DATE",
                        () => setState(() => scheduleFrequency = "MONTHLY_DATE"),
                  ),
                  const SizedBox(width: 10),
                  _buildTogglePill(
                    "WEEKLY",
                    scheduleFrequency == "WEEKLY",
                        () => setState(() => scheduleFrequency = "WEEKLY"),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _inputField(scheduleFrequency == "MONTHLY_DATE" ? "Day of Month (1-31)" : "Day of Week (1=Mon, 7=Sun)", _scheduleValCtrl, Icons.calendar_today, isNum: true, onChanged: (v) => setState(() => scheduleValue = int.tryParse(v) ?? 1)),
            ]),

            const SizedBox(height: 20),
            _buildLaunchButton(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildCard(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryGreen, letterSpacing: 1.2)),
      const Divider(height: 25, thickness: 0.5),
      ...children
    ]),
  );

  Widget _buildTypeToggle() {
    return Row(
      children: [
        _buildTogglePill(
          "KULUKAL",
          chitType == "KULUKAL",
              () => _onChitTypeChanged("KULUKAL"),
        ),
        const SizedBox(width: 10),
        _buildTogglePill(
          "AUCTION",
          chitType == "AUCTION",
              () => _onChitTypeChanged("AUCTION"),
        ),
      ],
    );
  }

  Widget _buildPrizeToggle() {
    return Row(
      children: [
        _buildTogglePill(
          "CURVE",
          prizeMode == "CURVE",
              () => setState(() {
            prizeMode = "CURVE";
            _recalculateCurvePreview();
          }),
        ),
        const SizedBox(width: 10),
        _buildTogglePill(
          "FLAT",
          prizeMode == "FLAT",
              () => setState(() {
            prizeMode = "FLAT";
            _firstPrizeCtrl.clear();
            _lastPrizeCtrl.clear();
          }),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String t, bool v, Function(bool)? onC, {String? subtitle}) => SwitchListTile(title: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11)) : null, value: v, onChanged: onC, activeColor: primaryGreen, contentPadding: EdgeInsets.zero);

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)));

  //Widget _buildChoice(String t, bool s, VoidCallback onT) => ChoiceChip(label: Text(t), selected: s, onSelected: (v) => onT(), selectedColor: primaryGreen.withOpacity(0.2));

  Widget _inputField(String label, TextEditingController? ctrl, IconData icon, {bool isNum = false, Function(String)? onChanged}) => TextFormField(controller: ctrl, keyboardType: isNum ? TextInputType.number : TextInputType.text, onChanged: onChanged, style: const TextStyle(fontSize: 15), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20, color: primaryGreen), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)), validator: (v) => v == null || v.isEmpty ? "Required" : null);

  Widget _buildLaunchButton() => Container(width: double.infinity, height: 55, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: isLoading ? null : _handleCreateAndActivate, child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CREATE & ACTIVATE CHIT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))));

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false, // Prevents accidental closing
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (c) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 80),
            const SizedBox(height: 16),
            const Text("CHIT IS ACTIVE!",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Group created and configured successfully.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  // FIXED: Replace stack with Dashboard instead of popping to Login
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard', // Ensure this string matches your route in main.dart
                        (route) => false,
                  );
                },
                child: const Text(
                  "GO TO DASHBOARD",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTogglePill(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryGreen : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primaryGreen : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recalculateCurvePreview() async {
    if (_amountCtrl.text.isEmpty ||
        _monthsCtrl.text.isEmpty ||
        prizeMode != "CURVE") {
      _firstPrizeCtrl.text = "";
      _lastPrizeCtrl.text = "";
      return;
    }

    final res = await ChitCreateApi.previewCurve({
      "chit_amount": int.parse(_amountCtrl.text),
      "duration_months": int.parse(_monthsCtrl.text),
      "chit_type": chitType,
      "prize_mode": prizeMode,
      "foreman_type": foremanType,        // "FULL_MONTH"
      "foreman_month": foremanMonth,      // e.g. 1
    });

    setState(() {
      _firstPrizeCtrl.text = res["start_amount"].toString();
      _lastPrizeCtrl.text = res["end_amount"].toString();
    });
  }
}