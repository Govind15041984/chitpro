import 'package:flutter/material.dart';
import '../../chit_create/data/chit_create_api.dart';

class MemberSlotsScreen extends StatefulWidget {
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
  State<MemberSlotsScreen> createState() => _MemberSlotsScreenState();
}

class _MemberSlotsScreenState extends State<MemberSlotsScreen> {
  late List<dynamic> _slots;

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.slots);
    debugPrint("SLOTS JSON: $_slots");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Slots"),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildAddSlotButton(),
            const SizedBox(height: 12),
            Expanded(child: _buildSlotList()),
          ],
        ),
      ),
    );
  }

  // ---------------- HEADER ----------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (widget.mobile != null && widget.mobile!.isNotEmpty)
            Text(widget.mobile!, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ---------------- ADD SLOT BUTTON ----------------
  Widget _buildAddSlotButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add),
        label: const Text("Add More Slots"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004D40),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _openAddSlotDialog,
      ),
    );
  }

  // ---------------- SLOT LIST ----------------
  Widget _buildSlotList() {
    if (_slots.isEmpty) {
      return const Center(child: Text("No slots assigned"));
    }

    return ListView.separated(
      itemCount: _slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final bool hasWon = slot["has_won"] == true;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            title: Row(
              children: [
                Text("Slot #${slot["member_no"]}"),
                const SizedBox(width: 8),
                if (hasWon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "WON",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
            subtitle: hasWon
                ? Text(
              "Won in Month ${slot["prize_month"]} • ₹${slot["payout_amount"]}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
                : null,
            trailing: hasWon
                ? const Icon(Icons.lock, color: Colors.grey) // 🔒 view-only
                : PopupMenuButton<String>(
              onSelected: (v) => _handleSlotAction(v, slot),
              itemBuilder: (_) => const [
                PopupMenuItem(value: "transfer", child: Text("Transfer Slot")),
                PopupMenuItem(value: "delete", child: Text("Remove Slot")),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- SLOT ACTIONS ----------------
  Future<void> _handleSlotAction(String action, dynamic slot) async {
    if (action == "delete") {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Remove Slot"),
          content: const Text("Are you sure you want to remove this slot?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Remove")),
          ],
        ),
      );

      if (confirm != true) return;

      await ChitCreateApi.deleteSlot(widget.chitGroupId, slot["id"]);

      setState(() {
        _slots.removeWhere((e) => e["id"] == slot["id"]);
      });

      Navigator.pop(context, true); // refresh members screen
    }

    if (action == "transfer") {
      _openTransferDialog(slot);
    }
  }

  // ---------------- TRANSFER SLOT ----------------
  void _openTransferDialog(dynamic slot) {
    final nameCtrl = TextEditingController(text: widget.name);
    final mobileCtrl = TextEditingController(text: widget.mobile ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Transfer Slot"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "New Name")),
            TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: "Mobile")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await ChitCreateApi.transferSlot(
                widget.chitGroupId,
                slot["id"],
                nameCtrl.text.trim(),
                mobileCtrl.text.trim().isEmpty ? null : mobileCtrl.text.trim(),
              );

              Navigator.pop(context);       // close dialog
              Navigator.pop(context, true); // refresh members list
            },
            child: const Text("Transfer"),
          ),
        ],
      ),
    );
  }

  // ---------------- ADD SLOT DIALOG ----------------
  void _openAddSlotDialog() {
    final slotCtrl = TextEditingController(text: "1");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add More Slots"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Adding slots for ${widget.name}"),
            const SizedBox(height: 8),
            TextField(
              controller: slotCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of slots"),
            ),
            const SizedBox(height: 8),
            const Text(
              "Joining month will be current month.\nCatch-up will be applied automatically.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final count = int.tryParse(slotCtrl.text.trim()) ?? 1;

              await ChitCreateApi.addSlotsWithCatchup(
                chitGroupId: widget.chitGroupId,
                name: widget.name,
                mobile: widget.mobile,
                slotCount: count,
              );

              Navigator.pop(context);        // close dialog
              Navigator.pop(context, true);  // refresh member list
            },
            child: const Text("Add Slots"),
          ),
        ],
      ),
    );
  }
}
