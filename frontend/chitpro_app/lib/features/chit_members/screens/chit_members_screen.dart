import 'package:flutter/material.dart';
import '../../chit_details/data/chit_group_api.dart';
import '../../chit_create/data/chit_create_api.dart';
import 'member_slots_screen.dart';
import 'member_ledger_screen.dart';
import '../widgets/add_member_dialog.dart';

class ChitMembersScreen extends StatefulWidget {
  final String chitGroupId;

  const ChitMembersScreen({super.key, required this.chitGroupId});

  @override
  State<ChitMembersScreen> createState() => _ChitMembersScreenState();
}

class _ChitMembersScreenState extends State<ChitMembersScreen> {
  late Future<Map<String, dynamic>> _summaryFuture;
  late Future<List<dynamic>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = ChitGroupApi.getSummary(widget.chitGroupId);
    _membersFuture = ChitCreateApi.listMembers(widget.chitGroupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          final summary = snap.data!;
          debugPrint("🧪 CHIT MEMBER SCREEN- SUMMARY FROM API: $summary");
          final bool isStarted = summary["is_current_month_started"] == true;
          // Get total_slots from the updated backend response
          final int totalSlotsLimit = summary["total_slots"] ?? 0;

          return FutureBuilder<List<dynamic>>(
            future: _membersFuture,
            builder: (context, mSnap) {
              // 1. Calculate the current occupied slots
              final List<dynamic> memberList = mSnap.data ?? [];
              final int currentCount = memberList.length;
              final bool isFull = totalSlotsLimit > 0 && currentCount >= totalSlotsLimit;

              return Column(
                children: [
                  // 2. Pass the 'isFull' and count data to the updated button helper
                  _buildAddMemberButton(isStarted, summary, isFull, currentCount, totalSlotsLimit),

                  Expanded(
                    child: Builder(builder: (context) {
                      if (mSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!mSnap.hasData || memberList.isEmpty) {
                        return _buildEmptyState();
                      }

                      final grouped = <String, List<dynamic>>{};
                      for (final m in memberList) {
                        final key = "${m["name"]}__${m["mobile_number"] ?? ""}";
                        grouped.putIfAbsent(key, () => []).add(m);
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: grouped.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final slots = grouped.values.elementAt(index);
                          final first = slots.first;
                          return _buildMemberCard(first, slots);
                        },
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildAddMemberButton(bool isStarted, Map<String, dynamic> summary, bool isFull, int current, int limit) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(
            isStarted ? Icons.lock_outline : (isFull ? Icons.block : Icons.person_add),
            color: Colors.white
        ),
        label: Text(
          isStarted
              ? "MONTH STARTED (Add Locked)"
              : (isFull ? "GROUP FULL ($current / $limit)" : "ADD MEMBER / SLOTS"),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isStarted ? Colors.grey : (isFull ? Colors.orange.shade900 : const Color(0xFF004D40)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
          onPressed: (isStarted || isFull) ? null : () async {
            final added = await showDialog(
              context: context,
              builder: (_) => AddMemberDialog(
                chitGroupId: widget.chitGroupId,
                currentMonth: summary["current_month"],          // 🔥 pass this
                monthlyDue: summary["installment_amount"],       // 🔥 pass this
              ),
            );

            if (added == true) {
              setState(() {
                _load(); // refresh summary + members
              });
            }
          }

      ),
    );
  }

  Widget _buildMemberCard(dynamic first, List<dynamic> slots) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
          child: Text(
            first["name"][0].toUpperCase(),
            style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          first["name"],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Slots: ${slots.map((e) => e["member_no"]).join(", ")}",
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF004D40)),
          onSelected: (v) async => _handleMenuAction(v, first, slots),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: "manage",
              child: Row(children: [Icon(Icons.edit_note, size: 20), SizedBox(width: 8), Text("Manage Slots")]),
            ),
            const PopupMenuItem(
              value: "ledger",
              child: Row(children: [Icon(Icons.list_alt, size: 20), SizedBox(width: 8), Text("View Ledger")]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String v, dynamic first, List<dynamic> slots) async {
    debugPrint("PASSING SLOTS: $slots");
    if (v == "manage") {
      final changed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberSlotsScreen(
            chitGroupId: widget.chitGroupId,
            name: first["name"],
            mobile: first["mobile_number"],
            slots: slots,
          ),
        ),
      );
      if (changed == true) setState(_load);
    } else if (v == "ledger") {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberLedgerScreen(
            personKey: first["mobile_number"] ?? "",
            name: first["name"],
            chitGroupId: widget.chitGroupId,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No members added yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}