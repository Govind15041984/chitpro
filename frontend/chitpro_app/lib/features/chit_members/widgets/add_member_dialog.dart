import 'package:flutter/material.dart';
import '../../chit_create/data/chit_create_api.dart';

class AddMemberDialog extends StatefulWidget {
  final String chitGroupId;
  final int currentMonth;
  final int monthlyDue;
  final String? prefillName;
  final String? prefillMobile;
  final bool readOnlyIdentity;

  const AddMemberDialog({
    super.key,
    required this.chitGroupId,
    required this.currentMonth,
    required this.monthlyDue,
    this.prefillName,
    this.prefillMobile,
    this.readOnlyIdentity = false,
  });

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  late TextEditingController nameCtrl;
  late TextEditingController mobileCtrl;
  int slotCount = 1;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.prefillName ?? "");
    mobileCtrl = TextEditingController(text: widget.prefillMobile ?? "");
  }

  @override
  Widget build(BuildContext context) {
    final int joiningMonth =
        (widget.currentMonth > 0 ? widget.currentMonth : 0) + 1;
    final effectiveMonthlyDue =
    widget.monthlyDue <= 0 ? 0 : widget.monthlyDue;

    final catchupPerSlot = joiningMonth * effectiveMonthlyDue;
    final totalPayable = catchupPerSlot * slotCount;

    return AlertDialog(
      title: const Text("Add Member / Slots"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              readOnly: widget.readOnlyIdentity,
              decoration: const InputDecoration(labelText: "Member Name"),
            ),
            TextField(
              controller: mobileCtrl,
              readOnly: widget.readOnlyIdentity,
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
                      onPressed:
                      slotCount > 1 ? () => setState(() => slotCount--) : null,
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
            Text("Joining Month: $joiningMonth"),
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
