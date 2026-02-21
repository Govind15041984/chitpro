import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/chit_create_provider.dart';
import '../state/chit_create_state.dart';
import 'add_chit_basic_info_screen.dart';
import 'chit_rule_settings_screen.dart';

class ChitCreateWizardScreen extends ConsumerWidget {
  const ChitCreateWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(chitCreateProvider);
    final step = controller.uiStep;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        title: const Text("Create Chit Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressHeader(step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildStepScreen(step),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(ChitCreateStep currentStep) {
    return Container(
      color: const Color(0xFF004D40),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: ChitCreateStep.values.map((s) {
          final bool isPast = s.index < currentStep.index;
          final bool isCurrent = s.index == currentStep.index;

          return Expanded(
            child: Row(
              children: [
                // Step Circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCurrent ? Colors.orangeAccent : (isPast ? Colors.white24 : Colors.white10),
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Center(
                    child: isPast
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text("${s.index + 1}", style: TextStyle(color: isCurrent ? Colors.black : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(s.label, style: TextStyle(color: isCurrent ? Colors.white : Colors.white38, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                if (s.index == 0) const Expanded(child: Divider(color: Colors.white12, indent: 8, endIndent: 8)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepScreen(ChitCreateStep step) {
    switch (step) {
      case ChitCreateStep.draft: return const AddChitBasicInfoScreen();
      case ChitCreateStep.configured: return const ChitRuleSettingsScreen();
    }
  }
}