import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../chit_create/create_chitrules_screen.dart';
import '../../chit_create/data/chit_create_api.dart';
import '../data/auction_api.dart';
import '../data/chit_group_api.dart';
import '../data/member_ledger_api.dart';
import 'auction_screen.dart';
import '../../chit_members/screens/chit_members_screen.dart';
import 'auction_history_screen.dart';
import 'chit_communication_hub.dart';

enum AuctionUiState {
  notStarted,
  winnerPending,
  collectionPending,
  readyToClose,
  completed,
}

class ChitDetailScreen extends StatefulWidget {
  final String chitGroupId;

  const ChitDetailScreen({
    super.key,
    required this.chitGroupId,
  });

  @override
  State<ChitDetailScreen> createState() => _ChitDetailScreenState();
}

class _ChitDetailScreenState extends State<ChitDetailScreen> {
  late Future<Map<String, dynamic>> _summaryFuture;
  double _reserveTotal = 0;
  double _dividendTotal = 0;

  @override
  void initState() {
    super.initState();
    _summaryFuture = ChitGroupApi.getSummary(widget.chitGroupId);
    _reloadSummary();
  }

  void _reloadSummary() async {
    final summary = await ChitGroupApi.getSummary(widget.chitGroupId);

    double reserveTotal = 0;
    final reserve = await ChitGroupApi.getReserveSummary(widget.chitGroupId);
    reserveTotal = (reserve["total"] ?? 0).toDouble();

    print("🔥 SUMMARY dividend_total = ${summary["dividend_total"]}");
    print("🔥 RESERVE total = ${reserve["total"]}");
    if (!mounted) return;

    setState(() {
      _summaryFuture = Future.value(summary);
      _reserveTotal = reserveTotal;
      _dividendTotal = (summary["dividend_total"] ?? 0).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        title: const Text("Chit Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Unable to load chit summary"));
          }

          final s = snapshot.data!;
          // Logic to check if the chit is closed/completed
          final String status = s["status"]?.toString().toUpperCase() ?? "";
          final bool isClosed = status == "CLOSED" || status == "COMPLETED";

          final int rawMonth = (s["current_month"] is int) ? s["current_month"] as int : 0;
          final int currentMonth = rawMonth <= 0 ? 1 : rawMonth;
          final int durationMonths = (s["duration_months"] is int && s["duration_months"] > 0) ? s["duration_months"] as int : 1;
          final bool isFinalMonth = currentMonth >= durationMonths;
          return Column(
            children: [
              // 0. READ-ONLY BANNER
              if (isClosed)
                Container(
                  width: double.infinity,
                  color: Colors.blueGrey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Center(
                    child: Text(
                      "VIEW ONLY MODE • CHIT MATURED",
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),

              // 1. BRANDED HEADER SECTION
              _buildModernHeader(s, currentMonth, durationMonths),

              // 2. PRIMARY ACTION AREA (Hidden if closed)
              if (!isClosed) _buildConditionalActionButtons(s),

              // 3. TABS SECTION
              Expanded(
                child: DefaultTabController(
                  //length: 4,
                  length: 3,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: const TabBar(
                          isScrollable: true,
                          labelColor: Color(0xFF004D40),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF004D40),
                          indicatorWeight: 3,
                          tabs: [
                            //Tab(text: "Members"),
                            Tab(text: "Auction"),
                            Tab(text: "Auction History"),
                            Tab(text: "Schedule"),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            //ChitMembersScreen(chitGroupId: widget.chitGroupId),
                            SingleChildScrollView(child: _AuctionSection(chitGroupId: widget.chitGroupId, isClosed: isClosed, isFinalMonth: isFinalMonth,)),
                            AuctionHistoryTab(chitGroupId: widget.chitGroupId),
                            _ScheduleTab(
                              chitGroupId: widget.chitGroupId,
                              summary: s,
                              onUpdated: _reloadSummary,
                              isClosed: isClosed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(Map<String, dynamic> s, int current, int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25), // Adjusted padding
      decoration: const BoxDecoration(
        color: Color(0xFF004D40),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s["group_name"], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("Total Value: ₹${s["chit_amount"]}", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
              _buildCircularProgress(current, total),
            ],
          ),

          // --- NEW MINIMALIST ACTION ROW (SPACE SAVER) ---
          const SizedBox(height: 18),
          Row(
            children: [
              _headerActionBtn(Icons.rule_folder_outlined, "RULES", () {
                // Check against the CORRECT key from your log: duration_months
                if (s["duration_months"] == null || s["chit_amount"] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Group data is incomplete..."))
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChitRulesScreen(
                      chitGroupId: widget.chitGroupId,
                      groupName: s["group_name"] ?? "Unnamed Group",
                      totalMonths: s["duration_months"], // FIXED KEY
                      chitAmount: s["chit_amount"],      // CORRECT KEY
                    ),
                  ),
                );
              }),
              _headerActionDivider(),
              _headerActionBtn(Icons.people_outline, "MEMBERS", () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChitMembersScreen(
                  chitGroupId: widget.chitGroupId,
                )));
              }),
              _headerActionDivider(),
              _headerActionBtn(Icons.campaign_outlined, "BROADCAST", () {
                final int nextMonth = (s["current_month"] ?? 0) + 1;

                ChitCommunicationHub.sendUpcomingAuctionBroadcastDirect(
                  context: context,
                  chitGroupId: widget.chitGroupId,
                  groupName: s["group_name"],
                  amount: s["chit_amount"].toString(),
                  whatsappGroupLink: s["whatsapp_group_link"],
                  next_run_date: s["next_run_date"],
                  current_month: nextMonth.toString(),
                );
              }),

            ],
          ),
          // ----------------------------------------------

          const SizedBox(height: 18),
          Row(
            children: [
              _headerStatCard("Installment", "₹${s["installment_amount"]}"),
              const SizedBox(width: 12),
              if (_dividendTotal > 0)
                _headerStatCard("Dividend", "₹${_dividendTotal.toStringAsFixed(0)}", icon: Icons.trending_up)
              else if (_reserveTotal > 0)
                _headerStatCard("Reserve", "₹${_reserveTotal.toStringAsFixed(0)}", icon: Icons.savings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(int current, int total) {
    double progress = total == 0 ? 0 : current / total;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 65,
          width: 65,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
        ),
        Text("$current/$total", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _headerStatCard(String label, String value, {IconData? icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (icon != null) Icon(icon, size: 14, color: Colors.greenAccent),
                if (icon != null) const SizedBox(width: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionalActionButtons(Map<String, dynamic> s) {
    final int currentMonth = s["current_month"] ?? 0;
    final int totalMonths = s["duration_months"] ?? 0;

    // 🔴 CASE 1: Chit ready to start
    if (s["status"] == "ACTIVE") {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _actionCard(
          "Chit is ready to start",
          "Start Chit",
          Colors.green,
          Icons.play_arrow,
              () async {
            await ChitCreateApi.startChit(widget.chitGroupId);
            _reloadSummary();
          },
        ),
      );
    }

    // 🟡 CASE 2: Last month completed → CLOSE CHIT
    if (s["status"] == "RUNNING" &&
        currentMonth >= totalMonths &&
        s["is_current_month_started"] != true) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _actionCard(
          "All months completed",
          "Close Chit",
          Colors.red,
          Icons.flag,
              () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Close Chit"),
                content: const Text("Are you sure you want to close this chit?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Close Chit")),
                ],
              ),
            );

            if (ok == true) {
              await ChitCreateApi.closeChit(widget.chitGroupId);
              _reloadSummary();
            }
          },
        ),
      );
    }

    // 🟢 CASE 3: Normal next month start
    if (s["status"] == "RUNNING" && s["is_current_month_started"] != true) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _actionCard(
          "Month ${currentMonth + 1} is ready",
          "Start Month – ${currentMonth + 1}",
          const Color(0xFF1A237E),
          Icons.calendar_today,
              () async {
            final confirmed = await _showConfirmStartMonth();
            if (confirmed == true) {
              await ChitGroupApi.startMonth(widget.chitGroupId);
              _reloadSummary();
            }
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _actionCard(String title, String btnLabel, Color color, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(icon, color: Colors.white),
                label: Text(btnLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmStartMonth() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Start Month"),
        content: const Text("Make sure all members are added.\nLate joiners won’t be included this month."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Start")),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.parse(iso);
    return "${dt.day}/${dt.month}/${dt.year}";
  }
  Widget _headerActionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white60),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _headerActionDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: 10,
      width: 1,
      color: Colors.white24,
    );
  }
}

class _AuctionSection extends StatelessWidget {
  final String chitGroupId;
  final bool isClosed;
  final bool isFinalMonth;
  const _AuctionSection({required this.chitGroupId, required this.isClosed, required this.isFinalMonth,});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isClosed ? "Auction Finalized" : "Active Auction Round", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          const SizedBox(height: 12),
          _CurrentAuctionCard(chitGroupId: chitGroupId, isClosed: isClosed, isFinalMonth: isFinalMonth, ),
        ],
      ),
    );
  }
}

class _CurrentAuctionCard extends StatefulWidget {
  final String chitGroupId;
  final bool isClosed;
  final bool isFinalMonth;
  const _CurrentAuctionCard({required this.chitGroupId, required this.isClosed, required this.isFinalMonth,});

  @override
  State<_CurrentAuctionCard> createState() => _CurrentAuctionCardState();
}

class _CurrentAuctionCardState extends State<_CurrentAuctionCard> {
  AuctionUiState? _state;
  Map<String, dynamic>? _auction;
  bool loading = true;
  bool _isMonthStarted = false;
  bool _allowExtraAuctionThisMonth = false;
  List<Map<String, dynamic>> _monthRounds = [];

  @override
  void initState() {
    super.initState();
    _loadAuction();
  }

  Future<void> _loadAuction() async {
    if (!mounted) return;
    setState(() => loading = true);

    final auction = await AuctionApi.getLiveAuction(widget.chitGroupId);
    final monthInfo = await ChitGroupApi.isMonthStarted(widget.chitGroupId);

    if (!mounted) return;

    List<Map<String, dynamic>> rounds = [];
    if (auction != null) {
      rounds = await AuctionApi.getMonthRounds(
        chitGroupId: widget.chitGroupId,
        monthNo: auction["month_no"],
      );
    }

    if (!mounted) return;

    final bool monthStarted = monthInfo["started"] == true;

    setState(() {
      _auction = auction;
      _monthRounds = rounds;
      loading = false;
      _isMonthStarted = monthStarted;   // 🔥 persist state

      if (!monthStarted) {
        _state = AuctionUiState.notStarted;
        _allowExtraAuctionThisMonth = false;
        return;
      }

      if (auction == null) {
        _state = AuctionUiState.notStarted;
      } else if (auction['status'] == 'CLOSED') {
        _state = AuctionUiState.completed;
      } else if (auction['winning_member_id'] == null && auction['is_auto'] != true) {
        _state = AuctionUiState.winnerPending;
      } else {
        _state = AuctionUiState.collectionPending;
      }

      _allowExtraAuctionThisMonth = auction?["can_run_extra_auction"] == true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _auction == null ? "Ready" : "Month ${_auction?['month_no']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                _statusBadge(),
              ],
            ),
            const Divider(height: 30),

            // 🏆 ROUND WINNERS + WHATSAPP BROADCAST
            if (_monthRounds.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Round Winners",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  if (_state == AuctionUiState.collectionPending)
                    TextButton.icon(
                      icon: const Icon(Icons.share, color: Colors.green, size: 18),
                      label: const Text(
                        "Broadcast",
                        style: TextStyle(color: Colors.green),
                      ),
                      onPressed: () {
                        ChitCommunicationHub.sendWinnerBroadcast(
                          context: context,
                          groupName: _auction?["group_name"] ?? "Chit Group",
                          chitAmount: (_auction?["chit_amount"] as num?)?.toInt() ?? 0,
                          monthNo: (_auction?["month_no"] as num?)?.toInt() ?? 0,
                          chitType: _auction?["chit_type"] ?? "KULUKAL",
                          monthlyDue: (_auction?["monthly_due"] as num?)?.toInt() ?? 0,
                          discountAmount: (_auction?["discount_amount"] as num?)?.toInt() ?? 0,
                          payoutAmount: (_auction?["payout_amount"] as num?)?.toInt() ?? 0, // 👈 use payout_amount
                          rounds: _monthRounds,
                        );

                      },

                    ),
                ],
              ),
              const SizedBox(height: 10),
              ..._monthRounds.map((r) => _buildRoundRow(r)),
              const SizedBox(height: 15),
            ],

            // 💰 COLLECTION SUMMARY
            if (_auction != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Collected: ₹${_auction!["total_collection"] ?? 0}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            if (!widget.isClosed) _actionButton(context),

            if (_auction != null &&
                (_state == AuctionUiState.collectionPending ||
                    (_auction?["is_auto"] == true &&
                        _auction?["auto_reason"] == "FOREMAN_MONTH")))
              _PaymentsSection(
                chitGroupId: widget.chitGroupId,
                monthNo: _auction!["month_no"],
                groupName: _auction?["group_name"] ?? "சிட் குரூப்",
                isClosed: widget.isClosed,
              ),
          ],
        ),
      ),
    );

  }

  Widget _buildRoundRow(Map<String, dynamic> r) {
    final bool isForeman =
        r["is_auto"] == true && r["auto_reason"] == "FOREMAN_MONTH";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isForeman
                  ? "Round ${r["round_no"]}: Company (Foreman)"
                  : (r["winning_member_name"] != null
                  ? "Round ${r["round_no"]}: ${r["winning_member_name"]}"
                  : "Round ${r["round_no"]}: Pending"),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            "₹${r["payout_amount"] ?? 0}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }



  Widget _statusBadge() {
    String text = _statusText();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  String _statusText() {
    if (_auction?["status"] == "WINNER_DECIDED") return "COLLECTION PENDING";
    if (_auction?["is_auto"] == true && _auction?["auto_reason"] == "FOREMAN_MONTH") return "FOREMAN MONTH";
    if (_state == null) return "UNKNOWN";
    return _state.toString().split('.').last.toUpperCase();
  }

  Widget _actionButton(BuildContext context) {
    final status = _auction?["status"];

    final bool isDisabled =
        !_isMonthStarted ||
        widget.isFinalMonth ||                       // 🔥 NEW: final month reached
        widget.isClosed ||                           // chit already closed
        status == "OPEN" ||
        status == "CLOSED" ||
        (status == "WINNER_DECIDED" && !_allowExtraAuctionThisMonth);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004D40),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: isDisabled
            ? null
            : () async {
          final auction = await AuctionApi.openAuctionRound(
            chitGroupId: widget.chitGroupId,
          );

          if (auction["is_auto"] == true &&
              auction["auto_reason"] == "FOREMAN_MONTH") {
            await _loadAuction();
            return;
          }

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AuctionScreen(
                chitGroupId: widget.chitGroupId,
                chitType: "KULUKAL",
                auctionRoundId: auction["id"],
              ),
            ),
          );

          if (result == true) {
            await _loadAuction();
            context.findAncestorStateOfType<_ChitDetailScreenState>()?._reloadSummary(); // 👈 ADD THIS
          }
        },
        child: Text(
          isDisabled ? "AUCTION COMPLETED" : "RUN AUCTION ROUND",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PaymentsSection extends StatefulWidget {
  final String chitGroupId;
  final int monthNo;
  final String groupName;
  final bool isClosed;

  const _PaymentsSection({required this.chitGroupId, required this.monthNo, required this.groupName, required this.isClosed});

  @override
  State<_PaymentsSection> createState() => _PaymentsSectionState();
}

class _PaymentsSectionState extends State<_PaymentsSection> {
  late Future<List<dynamic>> _duesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _duesFuture = MemberLedgerApi.getMonthlyDues(chitGroupId: widget.chitGroupId, monthNo: widget.monthNo);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _duesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final rows = snapshot.data!;
        // 🔥 SORT A → Z by member name
        rows.sort((a, b) {
          final nameA = (a["name"] ?? "").toString().toLowerCase();
          final nameB = (b["name"] ?? "").toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        final allCleared = rows.every((r) => (r["balance"] ?? 0) == 0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 40),
            const Text("Member Collections", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...rows.map((g) => _memberTile(g)),
            const SizedBox(height: 20),
            if (!widget.isClosed)
              allCleared
                  ? ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text("CLOSE MONTH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 45)),
                onPressed: () async {
                  await AuctionApi.closeMonth(widget.chitGroupId);
                  context.findAncestorStateOfType<_ChitDetailScreenState>()?._reloadSummary();
                  context.findAncestorStateOfType<_CurrentAuctionCardState>()?._loadAuction();
                },
              )
                  : const Center(child: Text("Close Month enabled after full collection", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        );
      },
    );
  }

  Widget _memberTile(Map<String, dynamic> g) {
    final bool paid = g["balance"] == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: paid ? Colors.green.shade100 : Colors.blue.shade100, child: Text(g["name"][0], style: TextStyle(color: paid ? Colors.green : Colors.blue))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g["name"], style: const TextStyle(fontWeight: FontWeight.bold)), Text("Bal: ₹${g["balance"]} / Due: ₹${g["total_due"]}", style: const TextStyle(fontSize: 12, color: Colors.grey))])),
          if (!paid && !widget.isClosed) ...[
            ChitCommunicationHub.buildContactActions(g, widget.groupName),
            const SizedBox(width: 12),
          ],
          paid || widget.isClosed
              ? const Icon(Icons.check_circle, color: Colors.green)
              : OutlinedButton(onPressed: () => _collectFromMember(g), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text("Collect", style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Future<void> _collectFromMember(Map<String, dynamic> g) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Collect – ${g["name"]}"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount received")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Collect")),
        ],
      ),
    );
    if (ok != true) return;
    await MemberLedgerApi.collectPartial(chitGroupId: widget.chitGroupId, personKey: g["person_key"], monthNo: widget.monthNo, amount: int.parse(controller.text));
    _load();
    context.findAncestorStateOfType<_CurrentAuctionCardState>()?._loadAuction();
  }
}

class _ScheduleTab extends StatelessWidget {
  final String chitGroupId;
  final Map<String, dynamic> summary;
  final VoidCallback onUpdated;
  final bool isClosed;

  const _ScheduleTab({
    required this.chitGroupId,
    required this.summary,
    required this.onUpdated,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    // Safely extract values as Strings to prevent TypeErrors
    final dynamic nextRunRaw = summary["next_run_date"];
    final dynamic ruleRaw = summary["schedule_rule"];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
              icon: Icons.event,
              title: "Next Auction Date",
              value: nextRunRaw != null ? _format(nextRunRaw.toString()) : "Not scheduled"
          ),
          const SizedBox(height: 12),
          _infoCard(
              icon: Icons.repeat,
              title: "Schedule Rule",
              value: ruleRaw != null ? _formatRule(ruleRaw.toString()) : "Not configured"
          ),
          const SizedBox(height: 24),

          // Button is disabled if chit is closed
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_calendar),
            label: const Text("Change Next Auction Date"),
            onPressed: isClosed ? null : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                await ChitGroupApi.updateNextRunDate(chitGroupId, picked.toIso8601String());
                onUpdated();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Next auction date updated")),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.campaign),
            label: const Text("Send WhatsApp Reminder"),
            onPressed: () {
              // We add '?? ""' to ensure if a value is null, it passes an empty string instead of crashing
              ChitCommunicationHub.openBroadcastDialog(
                context: context,
                chitGroupId: chitGroupId,
                groupName: summary["group_name"] ?? "Group",
                amount: (summary["chit_amount"] ?? 0).toString(),
                whatsappGroupLink: summary["whatsapp_group_link"]?.toString() ?? "",
                next_run_date: summary["next_run_date"]?.toString() ?? "", // Fixed the Null crash here
                current_month: summary["current_month"]?.toString() ?? "1", // Fixed the Null crash here
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
              child: Icon(icon, color: const Color(0xFF004D40))
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(color: Colors.grey))
                  ]
              )
          ),
        ],
      ),
    );
  }

  String _format(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return iso; // Return raw string if parsing fails
    }
  }

  String _formatRule(String rule) {
    if (rule.toUpperCase().contains("MONTHLY")) return "Monthly Schedule";
    return rule;
  }
}