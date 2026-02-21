import 'package:chitpro_app/features/dashboard/screens/testscreen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../api/dashboard_api.dart';
import '../../chit_create/create_newchit_screen.dart';
import '../../chit_details/screens/chit_communication_hub.dart';
import '../../my_chits/screens/my_chits_screen.dart';
import '../../subscription/screens/subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;

  // Dashboard Data
  String adminName = "Admin";
  String avatarLetter = "A";
  String plan = "FREE";
  int activeGroupsCount = 0;
  int monthlyCollected = 0;
  int monthlyPending = 0;
  int groupLimit = 1;
  List<dynamic> chitGroups = [];
  Map<String, dynamic>? liveAuction;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await DashboardApi.loadDashboard();
      setState(() {
        adminName = data["admin"]["name"]?.toString() ?? "Admin";
        avatarLetter = data["admin"]["avatar_letter"]?.toString() ?? "A";
        plan = data["admin"]["plan"]?.toString() ?? "FREE";

        activeGroupsCount = data["summary"]["active_chits_count"] ?? 0;
        monthlyCollected = data["summary"]["monthly_collected"] ?? 0;
        monthlyPending = data["summary"]["monthly_pending"] ?? 0;
        groupLimit = data["summary"]["group_limit"] ?? 1;

        chitGroups = data["groups"] ?? [];
        liveAuction = data["live_auction"];
        loading = false;
      });
    } catch (e) {
      debugPrint("Dashboard Error: $e");
      setState(() => loading = false);
    }
  }

  // Logic to handle New Chit Creation (Moved from FAB)
  void _handleNewChitAction() async {
    // Use the dynamic groupLimit from the server instead of hardcoding ">= 1"
    if (activeGroupsCount >= groupLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You've reached your limit of $groupLimit groups. Upgrade to Pro for unlimited access!"),
          backgroundColor: Colors.deepOrange,
          action: SnackBarAction(
            label: 'UPGRADE',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SubscriptionScreen()),
              ).then((_) => _loadDashboard());
            },
          ),
        ),
      );

      // Also navigate automatically after a short delay or immediately
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubscriptionScreen()),
      ).then((_) => _loadDashboard());

    } else {
      // THE HOOK: Navigate to your new standalone screen
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateNewChitScreen()),
      );

      // Refresh the dashboard data when the user comes back
      // (to show the new DRAFT count or group list)
      _loadDashboard();
    }
  }

  String _formatAmountBadge(int amount) {
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      return lakhs % 1 == 0 ? "${lakhs.toInt()}L" : "${lakhs.toStringAsFixed(1)}L";
    }
    return "₹$amount";
  }

  // --- QUICK ACTIONS SECTION ---
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        children: [
          _actionIcon(Icons.layers_outlined, "My Chits", Colors.teal, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyChitsScreen()));
          }),
          // REPLACED NOTIFY WITH NEW CHIT
          _actionIcon(Icons.add_box_outlined, "New Chit", Colors.orange, _handleNewChitAction),

          _actionIcon(Icons.receipt_long_outlined, "Ledger", Colors.blueGrey, () {}),
          _actionIcon(Icons.settings_outlined, "Settings", Colors.blue, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubscriptionScreen()),
            ).then((_) => _loadDashboard());
          }),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            height: 55, width: 55,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  // --- REMAINDER OF YOUR UI CODE ---

  Widget _buildUpcomingAuctions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = chitGroups.where((g) {
      final raw = g["next_run_date"];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return false;
      final runDate = DateTime(dt.year, dt.month, dt.day);
      final diff = runDate.difference(today).inDays;
      return diff >= 0 && diff <= 15;
    }).toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20, right: 10),
        itemCount: upcoming.length,
        itemBuilder: (context, index) {
          final g = upcoming[index];
          final rawDate = g["next_run_date"]?.toString();
          final runDate = rawDate != null ? DateTime.tryParse(rawDate) : null;
          if (runDate == null) return const SizedBox.shrink();
          final days = runDate.difference(now).inDays;

          String badge; Color badgeColor;
          if (days == 0) { badge = "TODAY"; badgeColor = Colors.red; }
          else if (days <= 2) { badge = "SOON"; badgeColor = Colors.orange; }
          else { badge = "IN $days DAYS"; badgeColor = Colors.blue; }

          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/chit-detail', arguments: g["id"]),
            child: Container(
              width: 260, margin: const EdgeInsets.only(right: 14), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 6))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(badge, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11))),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(_formatAmountBadge(g["chit_amount"] ?? 0), style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 12))),
                  ]),
                  const SizedBox(height: 12),
                  Text(g["group_name"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text("Next auction: ${runDate.day}/${runDate.month}/${runDate.year}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.campaign, size: 16),
                      label: const Text("Send Reminder", style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => ChitCommunicationHub.openBroadcastDialog(
                        context: context, chitGroupId: g["id"], groupName: g["group_name"] ?? "", amount: g["chit_amount"].toString(),
                        whatsappGroupLink: g["whatsapp_group_link"], next_run_date: rawDate ?? "", current_month: (g["current_month"] ?? 0).toString(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // FAB REMOVED FROM HERE
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : RefreshIndicator(
        onRefresh: _loadDashboard,
        color: const Color(0xFF004D40),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 160, pinned: true, backgroundColor: const Color(0xFF004D40), elevation: 0, automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(25, 60, 25, 0),
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF004D40), Color(0xFF00695C)])),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text("PLAN: ${plan.toUpperCase()}", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 10),
                        Text(adminName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ]),
                      CircleAvatar(radius: 26, backgroundColor: Colors.white.withOpacity(0.15), child: Text(avatarLetter.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFF00695C),
                child: Container(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35))),
                  child: Column(
                    children: [
                      const SizedBox(height: 25),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(children: [
                          _buildStatCard("Groups", activeGroupsCount.toString(), Icons.layers_outlined, const Color(0xFF004D40)),
                          const SizedBox(width: 15),
                          _buildStatCard("Pending", "₹${(monthlyPending / 1000).toStringAsFixed(1)}K", Icons.account_balance_wallet_outlined, Colors.redAccent),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      if (liveAuction != null) _buildLiveAuctionAlert(),
                      _buildSectionHeader("Quick Access"),
                      _buildQuickActions(),
                      _buildSectionHeader("Upcoming Auctions"),
                      _buildUpcomingAuctions(),
                      _buildSectionHeader("Financial Pulse"),
                      _buildCollectionProgress(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAuctionAlert() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        const Icon(Icons.campaign_rounded, color: Colors.orange),
        const SizedBox(width: 12),
        Expanded(child: Text("Auction Live: ${liveAuction!['group_name']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown))),
        TextButton(onPressed: () {}, child: const Text("JOIN")),
      ]),
    );
  }

  Widget _buildCollectionProgress() {
    double total = (monthlyCollected + monthlyPending).toDouble();
    double progress = total > 0 ? (monthlyCollected / total) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Collection Summary", style: TextStyle(color: Colors.white70)),
          Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: Colors.greenAccent, minHeight: 10, borderRadius: BorderRadius.circular(10)),
        const SizedBox(height: 16),
        Row(children: [ _subStat("Collected", "₹$monthlyCollected"), const Spacer(), _subStat("Pending", "₹$monthlyPending")])
      ]),
    );
  }

  Widget _subStat(String title, String val) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 30, 20, 15),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
    );
  }
}