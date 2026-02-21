import 'package:flutter/material.dart';
import '../../chit_create/data/chit_create_api.dart';
import '../data/chit_group_api.dart';

// =======================
// CHIT MEMBERS SCREEN
// =======================
class ChitMembersScreen extends StatefulWidget {
  final String chitGroupId;

  const ChitMembersScreen({
    super.key,
    required this.chitGroupId,
  });

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
      appBar: AppBar(title: const Text("Members")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summaryFuture,
        builder: (context, summarySnap) {
          if (!summarySnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = summarySnap.data!;
          final int currentMonth = (summary["current_month"] ?? 0);
          final int monthlyDue = (summary["installment_amount"] ?? 0) as int;

          return Column(
            children: [
              // HEADER
              Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        summary["group_name"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("Month $currentMonth"),
                    ],
                  ),
                ),
              ),

              // ADD BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Member / Slots"),
                    onPressed: () async {
                      final added = await showDialog(
                        context: context,
                        builder: (_) => _AddMemberDialogFromDetails(
                          chitGroupId: widget.chitGroupId,
                          currentMonth: currentMonth,
                          monthlyDue: monthlyDue,
                        ),
                      );

                      if (added == true) {
                        setState(_load);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // MEMBERS LIST (GROUPED)
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _membersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No members added yet"),
                      );
                    }

                    final members = snapshot.data!;

                    // 🔥 GROUP MEMBERS BY NAME + MOBILE
                    final Map<String, List<dynamic>> grouped = {};
                    for (final m in members) {
                      final key =
                          "${m["name"]}__${m["mobile_number"] ?? ""}";
                      grouped.putIfAbsent(key, () => []).add(m);
                    }

                    final groupedList = grouped.values.toList();

                    return ListView.builder(
                      itemCount: groupedList.length,
                      itemBuilder: (context, index) {
                        final slots = groupedList[index];
                        final first = slots.first;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(slots.length.toString()),
                            ),
                            title: Text(first["name"]),
                            subtitle: Text(
                              "Slots: ${slots.map((e) => e["member_no"]).join(", ")}",
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == "manage") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemberSlotsScreen(
                                        chitGroupId: widget.chitGroupId,
                                        name: first["name"],
                                        mobile: first["mobile_number"],
                                        slots: slots,
                                      ),
                                    ),
                                  ).then((_) => setState(_load));
                                } else if (value == "ledger") {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MemberLedgerScreen(
                                        memberId: first["id"],
                                        name: first["name"],
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: "manage",
                                  child: ListTile(
                                    leading: Icon(Icons.settings),
                                    title: Text("Manage Slots"),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: "ledger",
                                  child: ListTile(
                                    leading: Icon(Icons.receipt_long),
                                    title: Text("View Ledger"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================
// ADD MEMBER / SLOT DIALOG (UNCHANGED)
// =====================================================
class _AddMemberDialogFromDetails extends StatefulWidget {
  final String chitGroupId;
  final int currentMonth;
  final int monthlyDue;

  const _AddMemberDialogFromDetails({
    required this.chitGroupId,
    required this.currentMonth,
    required this.monthlyDue,
  });

  @override
  State<_AddMemberDialogFromDetails> createState() =>
      _AddMemberDialogFromDetailsState();
}

class _AddMemberDialogFromDetailsState
    extends State<_AddMemberDialogFromDetails> {
  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  int slotCount = 1;

  @override
  Widget build(BuildContext context) {
    final int joiningMonth =
        (widget.currentMonth > 0 ? widget.currentMonth : 0) + 1;
    final int effectiveMonth = joiningMonth;
    final effectiveMonthlyDue = widget.monthlyDue <= 0 ? 0 : widget.monthlyDue;

    final catchupPerSlot = effectiveMonth * effectiveMonthlyDue;
    final totalPayable = catchupPerSlot * slotCount;

    return AlertDialog(
      title: const Text("Add Member / Slots"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Member Name"),
            ),
            TextField(
              controller: mobileCtrl,
              decoration:
              const InputDecoration(labelText: "Mobile (optional)"),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Slots"),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: slotCount > 1
                          ? () => setState(() => slotCount--)
                          : null,
                    ),
                    Text(slotCount.toString()),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => slotCount++),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text("Joining Month: $effectiveMonth"),
            Text(
              "Total Payable: ₹$totalPayable",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _onAddPressed,
          child: const Text("Add"),
        ),
      ],
    );
  }

  Future<void> _onAddPressed() async {
    if (nameCtrl.text.isEmpty) return;

    if (slotCount > 1) {
      await ChitCreateApi.addSlotsWithCatchup(
        chitGroupId: widget.chitGroupId,
        name: nameCtrl.text,
        mobile: mobileCtrl.text.isEmpty ? null : mobileCtrl.text,
        slotCount: slotCount,
      );
    } else {
      await ChitCreateApi.addMemberWithCatchup(
        chitGroupId: widget.chitGroupId,
        name: nameCtrl.text,
        mobile: mobileCtrl.text.isEmpty ? null : mobileCtrl.text,
        memberNo: 0,
      );
    }

    Navigator.pop(context, true);
  }
}

// =====================================================
// STUB SCREENS (REPLACE LATER)
// =====================================================
class MemberSlotsScreen extends StatelessWidget {
  final String chitGroupId;
  final String name;
  final String? mobile;
  final List<dynamic> slots;

  const MemberSlotsScreen({
    super.key,
    required this.chitGroupId,
    required this.name,
    required this.mobile,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Slots")),
      body: Center(
        child: Text("TODO: Slot management for $name"),
      ),
    );
  }
}

class MemberLedgerScreen extends StatelessWidget {
  final String memberId;
  final String name;

  const MemberLedgerScreen({
    super.key,
    required this.memberId,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Member Ledger")),
      body: Center(
        child: Text("TODO: Ledger for $name"),
      ),
    );
  }
}
