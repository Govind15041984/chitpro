import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/chit_create_provider.dart';

class ChitStartScreen extends ConsumerWidget {
  const ChitStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chitCreateProvider);
    final draft = controller.draft;

    final schedule =
    draft.ruleSettings?["schedule_rule"] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScheduleSummary(schedule, draft.totalMonths),
          const SizedBox(height: 16),
          _buildPreviewCard(),
          const Spacer(),
          _buildDoneButton(context), // ✅ FIXED
        ],
      ),
    );
  }

  // ================= READ-ONLY SCHEDULE SUMMARY =================
  Widget _buildScheduleSummary(Map<String, dynamic>? schedule, int months) {
    String text = "-";

    if (schedule != null) {
      if (schedule["frequency"] == "MONTHLY_DATE") {
        text =
        "Auction will run every month on day ${schedule["day"]}, "
            "for $months months.";
      } else if (schedule["frequency"] == "MONTHLY_WEEKDAY") {
        text =
        "Auction will run every month on week ${schedule["week"]}, "
            "weekday ${schedule["weekday"]}, for $months months.";
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Auction Schedule",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }

  // ================= PREVIEW =================
  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Chit Created Successfully",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("You can now start auctions from Chit Details screen."),
          ],
        ),
      ),
    );
  }

  // ================= DONE =================
  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.all(14),
        ),
        onPressed: () {
          Navigator.pop(context); // go back to dashboard / chit list
        },
        child: const Text("Done"),
      ),
    );
  }
}
