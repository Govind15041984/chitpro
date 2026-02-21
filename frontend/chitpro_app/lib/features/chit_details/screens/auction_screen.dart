import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart'; // Audio import
import '../data/auction_api.dart';

class EligibleSlot {
  final String id;
  final String name;
  final int memberNo;
  EligibleSlot({required this.id, required this.name, required this.memberNo});
}

enum WinnerMode { spin, manual }

class AuctionScreen extends StatefulWidget {
  final String chitGroupId;
  final String chitType;
  final String auctionRoundId;

  const AuctionScreen({
    super.key,
    required this.chitGroupId,
    required this.chitType,
    required this.auctionRoundId,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  // --- CONTROLLERS ---
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio Player
  final TextEditingController manualAmountCtrl = TextEditingController();

  // --- STATE ---
  WinnerMode winnerMode = WinnerMode.spin;
  List<EligibleSlot> eligibleSlots = [];
  Set<String> selectedSlotIds = {};
  EligibleSlot? winner;
  int? spinningIndex;
  bool isSpinning = false;
  bool loading = true;
  int? monthNo;

  bool get isKulukal => widget.chitType == "KULUKAL" || widget.chitType == "SIMPLE_KULUKAL";

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    manualAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final auction = await AuctionApi.getLiveAuction(widget.chitGroupId);
    monthNo = auction?['month_no'];
    final members = await AuctionApi.getEligibleMembers(widget.chitGroupId, monthNo!, "");
    eligibleSlots = members
        .where((m) => m['slot_no'] != null)
        .map((m) => EligibleSlot(
      id: m['id'] as String,
      name: m['name'] as String,
      memberNo: (m['slot_no'] as num).toInt(),
    ))
        .toList();
    setState(() => loading = false);
  }

  // --- SOUND LOGIC ---
  void _playTick() => _audioPlayer.play(AssetSource('sounds/tick.mp3'), volume: 0.5);
  void _playWin() => _audioPlayer.play(AssetSource('sounds/win.mp3'), volume: 1.0);

  // --- SPIN LOGIC ---
  Future<void> _spinWinner() async {
    if (selectedSlotIds.isEmpty) return;

    _confettiController.stop();
    setState(() {
      isSpinning = true;
      winner = null;
    });

    final activeIds = eligibleSlots.asMap().entries
        .where((e) => selectedSlotIds.contains(e.value.id))
        .map((e) => e.key)
        .toList();

    int rounds = 35 + Random().nextInt(10);
    int delay = 40;

    for (int i = 0; i < rounds; i++) {
      await Future.delayed(Duration(milliseconds: delay));
      setState(() => spinningIndex = activeIds[i % activeIds.length]);

      // TICK SOUND + HAPTIC
      _playTick();
      HapticFeedback.selectionClick();

      // Gradual Slowdown for Suspense
      if (i > rounds * 0.6) delay += 25;
      if (i > rounds * 0.85) delay += 60;
    }

    setState(() {
      winner = eligibleSlots[spinningIndex!];
      isSpinning = false;
    });

    // WIN SOUND + CONFETTI + VIBRATION
    _playWin();
    HapticFeedback.vibrate();
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        title: const Text("Chit Lucky Draw", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            children: [
              _buildWinnerSlot(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildModeSelector(),
                      const SizedBox(height: 16),
                      if (winnerMode == WinnerMode.spin) _buildSelectionList(),
                      if (winnerMode == WinnerMode.manual) _buildManualEntry(),
                    ],
                  ),
                ),
              ),
              _buildActionFooter(),
            ],
          ),

          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.amber, Colors.green, Colors.blue, Colors.pink],
            numberOfParticles: 30,
            gravity: 0.1,
          ),
        ],
      ),
    );
  }

  // UI Helper widgets (_buildWinnerSlot, _buildModeSelector, etc.) would follow the same
  // design as the previous response, now optimized for the audio/confetti flow.
  // ... [Include the UI methods from the previous version here] ...

  Widget _buildWinnerSlot() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 40, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF004D40),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Text(isSpinning ? "CYCLING SLOTS..." : "RESULT",
              style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            height: 120,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: isSpinning ? Colors.orangeAccent : Colors.white24, width: 2),
            ),
            child: Center(
              child: isSpinning
                  ? Text(
                eligibleSlots[spinningIndex ?? 0].name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 28, fontWeight: FontWeight.w900),
              )
                  : winner == null
                  ? const Text("Ready to Spin", style: TextStyle(color: Colors.white38, fontSize: 18))
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(winner!.name.toUpperCase(),
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Slot No: ${winner!.memberNo}", style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [Remaining UI logic for mode selector, selection list, manual entry, and footer from the previous version]
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _modeButton("Spin Draw", WinnerMode.spin)),
          Expanded(child: _modeButton("Manual Entry", WinnerMode.manual)),
        ],
      ),
    );
  }

  Widget _modeButton(String label, WinnerMode mode) {
    bool active = winnerMode == mode;
    return GestureDetector(
      onTap: () => setState(() => winnerMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? Colors.teal : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildSelectionList() {
    final allSelected = selectedSlotIds.length == eligibleSlots.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Participants", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A237E))),
            TextButton(
              onPressed: isSpinning ? null : () {
                setState(() {
                  if (allSelected) selectedSlotIds.clear();
                  else selectedSlotIds = eligibleSlots.map((e) => e.id).toSet();
                });
              },
              child: Text(allSelected ? "Clear" : "Select All"),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: eligibleSlots.length,
          itemBuilder: (context, i) {
            final slot = eligibleSlots[i];
            final isSelected = selectedSlotIds.contains(slot.id);
            return Opacity(
              opacity: isSpinning && !isSelected ? 0.3 : 1.0,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade200)),
                child: CheckboxListTile(
                  value: isSelected,
                  activeColor: Colors.teal,
                  title: Text(slot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Slot ${slot.memberNo}"),
                  onChanged: isSpinning ? null : (v) => setState(() => v! ? selectedSlotIds.add(slot.id) : selectedSlotIds.remove(slot.id)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<EligibleSlot>(
              decoration: const InputDecoration(labelText: "Pick Winner"),
              items: eligibleSlots.map((s) => DropdownMenuItem(value: s, child: Text("${s.name} (${s.memberNo})"))).toList(),
              onChanged: (v) => setState(() => winner = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: manualAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Winning Bid Amount", prefixText: "₹ "),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          if (winnerMode == WinnerMode.spin)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isSpinning || selectedSlotIds.isEmpty ? null : _spinWinner,
                icon: const Icon(Icons.casino),
                label: const Text("SPIN"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          if (winnerMode == WinnerMode.spin) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: winner != null && !isSpinning ? _confirmAuction : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40)),
              child: const Text("CONFIRM WINNER"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAuction() async {
    final winningAmount = int.tryParse(manualAmountCtrl.text);
    await AuctionApi.closeAuctionRound(
      auctionRoundId: widget.auctionRoundId,
      winningMemberId: winner!.id,
      winningBidAmount: winningAmount,
    );
    Navigator.pop(context, true);
  }
}