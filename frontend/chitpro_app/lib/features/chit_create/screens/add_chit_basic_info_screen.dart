import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/chit_create_provider.dart';

class AddChitBasicInfoScreen extends ConsumerStatefulWidget {
  const AddChitBasicInfoScreen({super.key});

  @override
  ConsumerState<AddChitBasicInfoScreen> createState() => _AddChitBasicInfoScreenState();
}

class _AddChitBasicInfoScreenState extends ConsumerState<AddChitBasicInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameCtrl = TextEditingController();
  final _chitAmountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController();
  final _slotsCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(chitCreateProvider);
    final notifier = ref.read(chitCreateProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Core Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text("Set the foundation for your chit group. These details cannot be changed later.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 25),

            _buildField("Group Name", _groupNameCtrl, Icons.badge_outlined),
            _buildField("Total Chit Value (₹)", _chitAmountCtrl, Icons.account_balance_wallet_outlined, isNum: true),

            Row(
              children: [
                Expanded(child: _buildField("Months", _monthsCtrl, Icons.calendar_month, isNum: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildField("Slots", _slotsCtrl, Icons.people_outline, isNum: true)),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: controller.isLoading ? null : () async {
                  if (_formKey.currentState!.validate()) {
                    await notifier.createDraft(
                      groupName: _groupNameCtrl.text,
                      chitAmount: int.parse(_chitAmountCtrl.text),
                      totalMembers: int.parse(_slotsCtrl.text),
                      durationMonths: int.parse(_monthsCtrl.text),
                    );
                  }
                },
                child: controller.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Initialize Draft & Configure Rules",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF004D40), size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade200)
          ),
        ),
      ),
    );
  }
}