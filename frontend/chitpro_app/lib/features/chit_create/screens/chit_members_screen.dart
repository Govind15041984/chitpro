import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../state/chit_create_controller.dart';
import '../state/chit_create_provider.dart';
import '../models/member_slot.dart';

class ChitMembersScreen extends ConsumerWidget {
  const ChitMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chitCreateProvider);

    final members = controller.draft.members
        .map((m) => MemberSlot.fromJson(m))
        .toList()
      ..sort((a, b) => a.slotNo.compareTo(b.slotNo));

    return Column(
      children: [
        _buildAddMemberButton(context, controller, members),
        Expanded(
          child: _buildMemberList(
            members,
            controller,
            context,
          ),
        ),
        _buildFooter(
          context,
          members,
          controller,
        ),
      ],
    );
  }

  // ---------------- ADD MEMBER BUTTON ----------------
  Widget _buildAddMemberButton(
      BuildContext context,
      ChitCreateController controller,
      List<MemberSlot> members,
      ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.person_add),
          label: const Text("Add Member / Slots"),
          onPressed: () {
            final nextSlotNo =
            members.isEmpty ? 1 : members.last.slotNo + 1;

            _openMemberDialog(
              context,
              controller,
              nextSlotNo,
              null,
            );
          },
        ),
      ),
    );
  }

  // ---------------- MEMBER LIST ----------------
  Widget _buildMemberList(
      List<MemberSlot> members,
      ChitCreateController controller,
      BuildContext context,
      ) {
    if (members.isEmpty) {
      return const Center(
        child: Text("No members added yet"),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(member.slotNo.toString()),
            ),
            title: Text("${member.name} (Slot ${member.slotNo})"),
            subtitle: Text(member.mobile ?? ""),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _openMemberDialog(
                  context,
                  controller,
                  member.slotNo,
                  member,
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------- FOOTER ----------------
  Widget _buildFooter(
      BuildContext context,
      List<MemberSlot> members,
      ChitCreateController controller,
      ) {
    final canActivate = members.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canActivate
              ? () async {
            //await controller.saveMembersToBackend();
            //await controller.activateChit();
          }
              : null,
          child: const Text("Activate Chit & Continue"),
        ),
      ),
    );
  }

  // ---------------- MEMBER DIALOG (UPDATED) ----------------
  void _openMemberDialog(
      BuildContext context,
      ChitCreateController controller,
      int startSlotNo,
      MemberSlot? existing,
      ) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final mobileCtrl = TextEditingController(text: existing?.mobile);

    int slotCount = 1;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              existing == null ? "Add Member / Slots" : "Add More Slots",
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Member Name",
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mobileCtrl,
                  decoration: const InputDecoration(
                    labelText: "Mobile (optional)",
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // SLOT COUNT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Number of Slots",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: slotCount > 1
                              ? () => setState(() => slotCount--)
                              : null,
                        ),
                        Text(
                          slotCount.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => slotCount++),
                        ),
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  "Each slot participates independently.\n"
                      "New slots added later will be treated as late joiners.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Name is required")),
                    );
                    return;
                  }

                  // CREATE SLOTS
                  //for (int i = 0; i < slotCount; i++) {
                  //  controller.addOrUpdateMember(
                  //    slotNo: startSlotNo + i,
                  //    name: nameCtrl.text,
                  //    mobile: mobileCtrl.text,
                  //  );
                  //}

                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }
}
