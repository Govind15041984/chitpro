import 'package:flutter/material.dart';
import '../data/my_chits_api.dart';

class MyChitsScreen extends StatefulWidget {
  const MyChitsScreen({super.key});

  @override
  State<MyChitsScreen> createState() => _MyChitsScreenState();
}

class _MyChitsScreenState extends State<MyChitsScreen> {
  String searchQuery = "";
  bool isSearching = false;

  List<dynamic> activeChits = [];
  List<dynamic> closedChits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await MyChitsApi.fetchChits();

      setState(() {
        activeChits = data.where((c) {
          final status = c['lifecycle_status']?.toString().toUpperCase();
          return status != 'CLOSED' && status != 'COMPLETED';
        }).toList();

        closedChits = data.where((c) {
          final status = c['lifecycle_status']?.toString().toUpperCase();
          return status == 'CLOSED' || status == 'COMPLETED';
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  String _formatCompact(dynamic amount) {
    if (amount == null) return "0";
    double val = (amount as num).toDouble();
    if (val >= 100000) {
      double lakhs = val / 100000;
      return lakhs % 1 == 0 ? "${lakhs.toInt()}L" : "${lakhs.toStringAsFixed(1)}L";
    }
    if (val >= 1000) {
      double k = val / 1000;
      return k % 1 == 0 ? "${k.toInt()}K" : "${k.toStringAsFixed(1)}K";
    }
    return val.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF004D40),
          elevation: 0,
          title: isSearching
              ? _buildSearchField()
              : const Text(
            "Chit Inventory",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.white),
              onPressed: () => setState(() {
                isSearching = !isSearching;
                if (!isSearching) searchQuery = "";
              }),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.orangeAccent,
            indicatorWeight: 4,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [Tab(text: "ACTIVE"), Tab(text: "CLOSED")],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF004D40),
          child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
              : TabBarView(
            children: [
              _buildChitList(activeChits),
              _buildChitList(closedChits),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      autofocus: true,
      style: const TextStyle(color: Colors.white, fontSize: 18),
      cursorColor: Colors.orangeAccent,
      decoration: InputDecoration(
        hintText: "Search groups...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        border: InputBorder.none,
      ),
      onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
    );
  }

  Widget _buildChitList(List cards) {
    // Detect if this specific list instance is the closed list
    final bool isClosedTab = cards == closedChits;

    List filtered = cards.where((c) {
      final name = c['group_name'] ?? "";
      return name.toString().toLowerCase().contains(searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(Icons.layers_clear_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Center(child: Text("No chits found", style: TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final c = filtered[i];
        final int total = c['duration_months'] ?? 1;
        // If closed, we show full progress (total/total)
        final int current = isClosedTab ? total : (c['current_month'] ?? 0);
        final double progress = isClosedTab ? 1.0 : (current / total).clamp(0.0, 1.0);

        final int pending = isClosedTab ? 0 : (c['pending_amount'] ?? 0);
        final String chitType = (c['chit_type'] ?? "").toString().toUpperCase();
        final String amountBadge = _formatCompact(c['chit_amount'] ?? 0);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/chit-detail',
                arguments: {
                  'id': c['id'],
                  'isReadOnly': isClosedTab, // Pass the tab state
                  'status': c['lifecycle_status'],
                },
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ICON WITH FLOATING BADGE ---
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isClosedTab
                                  ? Colors.grey.withOpacity(0.1)
                                  : const Color(0xFF004D40).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                                Icons.account_balance_wallet,
                                color: isClosedTab ? Colors.blueGrey : const Color(0xFF004D40),
                                size: 24
                            ),
                          ),
                          Positioned(
                            top: -8,
                            left: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: isClosedTab ? Colors.blueGrey : Colors.orangeAccent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
                                  ]
                              ),
                              child: Text(
                                amountBadge,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // --- CHIT INFO SECTION ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (c['group_name'] ?? "Unnamed Group").toString().toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                  color: isClosedTab ? Colors.blueGrey : const Color(0xFF1E293B)
                              ),
                            ),
                            const SizedBox(height: 4),

                            if (chitType == "KULUKAL")
                              Text(
                                "Reserve: ₹${_formatCompact(c['reserve_amount'] ?? 0)}",
                                style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.w600),
                              )
                            else if (chitType == "AUCTION")
                              Text(
                                "Dividend: ₹${_formatCompact(c['dividend_earned'] ?? 0)}",
                                style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                              )
                            else
                              Text(
                                "Status: ${isClosedTab ? 'Completed' : (c['lifecycle_status'] ?? 'Active')}",
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),

                            const SizedBox(height: 2),
                            Text(
                              isClosedTab ? "Finalized Value: ₹${_formatCompact(c['chit_amount'] ?? 0)}" : "Total Value: ₹${_formatCompact(c['chit_amount'] ?? 0)}",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // --- RIGHT SIDE: DUE/CLOSED INDICATOR ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 38, width: 38,
                                child: CircularProgressIndicator(
                                  value: isClosedTab ? 1.0 : (pending > 0 ? 0.3 : 1.0),
                                  strokeWidth: 3.5,
                                  backgroundColor: Colors.grey.shade100,
                                  color: isClosedTab ? Colors.blue : (pending > 0 ? Colors.orange : Colors.green),
                                ),
                              ),
                              Icon(
                                isClosedTab ? Icons.check : (pending > 0 ? Icons.priority_high : Icons.check),
                                size: 14,
                                color: isClosedTab ? Colors.blue : (pending > 0 ? Colors.orange : Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isClosedTab ? "MATURED" : (pending > 0 ? "Due: ₹${_formatCompact(pending)}" : "Cleared"),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isClosedTab ? Colors.blue : (pending > 0 ? Colors.redAccent : Colors.green)
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // --- BOTTOM SECTION: MONTH PROGRESS ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isClosedTab ? "Cycle Completed" : "Month $current / $total",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text(isClosedTab ? "$total Mos" : "${(progress * 100).toInt()}% Paid",
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isClosedTab ? Colors.blueGrey : const Color(0xFF00695C)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}