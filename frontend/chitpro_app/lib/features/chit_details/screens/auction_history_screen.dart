import 'package:flutter/material.dart';
import '../data/auction_api.dart';
import '../data/chit_group_api.dart';

class AuctionHistoryTab extends StatefulWidget {
  final String chitGroupId;

  const AuctionHistoryTab({
    super.key,
    required this.chitGroupId,
  });

  @override
  State<AuctionHistoryTab> createState() => _AuctionHistoryTabState();
}

class _AuctionHistoryTabState extends State<AuctionHistoryTab> {
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = ChitGroupApi.getSummary(widget.chitGroupId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
        }

        if (!snap.hasData) return const Center(child: Text("No data available"));

        final summary = snap.data!;
        final int currentMonth = summary["current_month"] ?? 0;

        if (currentMonth == 0) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemCount: currentMonth,
          itemBuilder: (context, index) {
            final monthNo = currentMonth - index;

            return FutureBuilder<List<dynamic>>(
              future: AuctionApi.getMonthRounds(
                chitGroupId: widget.chitGroupId,
                monthNo: monthNo,
              ),
              builder: (context, roundsSnap) {
                if (roundsSnap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 80); // Smooth loading placeholder
                }

                final rounds = roundsSnap.data ?? [];
                return _buildMonthEntry(monthNo, rounds);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMonthEntry(int monthNo, List<dynamic> rounds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "MONTH $monthNo",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Expanded(child: Divider(indent: 10, endIndent: 10, color: Colors.black12)),
            ],
          ),
          const SizedBox(height: 10),
          if (rounds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 8),
              child: Text("Data pending...", style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...rounds.map((r) => _buildWinnerCard(monthNo, r)).toList(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildWinnerCard(int monthNo, dynamic r) {
    final bool isForeman = r["is_auto"] == true || r["winning_member_id"] == null;
    final String winnerName = isForeman ? "Company (Foreman)" : (r["winning_member_name"] ?? "Pending");

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items to center
              children: [
                // 1. Icon Box
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: isForeman ? const Color(0xFF1A237E).withOpacity(0.05) : const Color(0xFF004D40).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isForeman ? Icons.business_center_rounded : Icons.emoji_events_rounded,
                    color: isForeman ? const Color(0xFF1A237E) : const Color(0xFFFFB300),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Middle Content (Name & Subtitle) - Wrapped in Expanded
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FIX: Wrapped this Row in a flexible structure
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible( // Prevents long names from overflowing
                            child: Text(
                              winnerName,
                              overflow: TextOverflow.ellipsis, // Adds "..." if too long
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isForeman ? const Color(0xFF1A237E) : Colors.black87,
                              ),
                            ),
                          ),
                          if (isForeman)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, size: 14, color: Colors.blue),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isForeman ? "Standard Foreman Month" : "Slot: ${r["winning_member_no"]} • Round: ${r["round_no"]}",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8), // Gap between name and payout

                // 3. Payout Section - Fixed Width/Alignment
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("PAYOUT", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(
                      "₹${r["payout_amount"] ?? 0}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Dividend Info Row
          if (r["dividend_amount"] != null && r["dividend_amount"] > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.trending_down, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text("Member Dividend: ", style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  Text("₹${r["dividend_amount"]}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text("No auctions have been recorded yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}