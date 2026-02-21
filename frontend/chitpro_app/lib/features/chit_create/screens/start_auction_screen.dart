import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auction_round_controller.dart';
import '../state/auction_round_provider.dart';
import '../state/auction_round_state.dart';
import '../data/auction_api.dart';
import '/../api/config_api.dart';
import '/../core/auth_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StartAuctionScreen extends ConsumerStatefulWidget {
  final String chitGroupId;

  const StartAuctionScreen({super.key, required this.chitGroupId});

  @override
  ConsumerState<StartAuctionScreen> createState() => _StartAuctionScreenState();
}

class _StartAuctionScreenState extends ConsumerState<StartAuctionScreen> {
  final TextEditingController _memberCtrl = TextEditingController();
  final TextEditingController _bidCtrl = TextEditingController();

  String? selectedMemberId;
  String? selectedDisplay;

  @override
  void initState() {
    super.initState();
    ref.read(auctionRoundProvider(widget.chitGroupId).notifier).loadLiveRound();
  }

  Future<List<Map<String, dynamic>>> _searchMembers(String query) async {
    if (query.isEmpty) return [];

    final token = await AuthStorage.instance.getToken();
    final res = await http.get(
      Uri.parse('$kBaseUrl/chit-members/${widget.chitGroupId}/search?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];

    final List list = jsonDecode(res.body);
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auctionRoundProvider(widget.chitGroupId));
    final controller =
    ref.read(auctionRoundProvider(widget.chitGroupId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Auction"),
        backgroundColor: const Color(0xFF1A237E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.phase == AuctionPhase.open
            ? _buildLiveAuction(state, controller)
            : _buildOpenAuction(state, controller),
      ),
    );
  }

  Widget _buildOpenAuction(AuctionRoundState state, AuctionRoundController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("No Active Auction", style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        Text("Month: ${state.currentMonth}"),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text("Open Auction"),
          onPressed: () => controller.openRound(),
        ),
      ],
    );
  }

  Widget _buildLiveAuction(AuctionRoundState state, AuctionRoundController controller) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metric("Month", state.currentMonth.toString()),
          _metric("Prize Amount", "₹${state.prizeAmount ?? '-'}"),
          _metric("Dividend / Member", "₹${state.dividendPerMember ?? '-'}"),
          _metric("Reserve Pool", "₹${state.reservePool ?? '-'}"),

          const Divider(height: 32),
          const Text("Winner Entry", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              return await _searchMembers(textEditingValue.text);
            },
            displayStringForOption: (option) =>
            "${option['slot_no']} - ${option['name']}",
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: "Winning Member (Slot - Name)",
                  border: OutlineInputBorder(),
                ),
              );
            },
            onSelected: (option) {
              selectedMemberId = option["id"];
              selectedDisplay = "${option['slot_no']} - ${option['name']}";
            },
          ),

          const SizedBox(height: 12),

          if (!state.isKulukal)
            TextField(
              controller: _bidCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Winning Bid Amount",
                border: OutlineInputBorder(),
              ),
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text("Close Auction"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                if (selectedMemberId == null) {
                  _showError("Please select winning member");
                  return;
                }

                await controller.closeRound(
                  winningMemberId: selectedMemberId!,
                  bidAmount: state.isKulukal ? null : int.tryParse(_bidCtrl.text),
                );

                _memberCtrl.clear();
                _bidCtrl.clear();
                selectedMemberId = null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
