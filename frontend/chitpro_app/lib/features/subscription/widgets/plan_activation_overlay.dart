import 'dart:async';
import 'package:flutter/material.dart';

class PlanActivationOverlay extends StatefulWidget {
  final VoidCallback onCompleted;

  const PlanActivationOverlay({super.key, required this.onCompleted});

  @override
  State<PlanActivationOverlay> createState() => _PlanActivationOverlayState();
}

class _PlanActivationOverlayState extends State<PlanActivationOverlay>
    with SingleTickerProviderStateMixin {
  double _scale = 0.0;

  @override
  void initState() {
    super.initState();

    // Start animation
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => _scale = 1.0);
    });

    // Navigate after 1.2 sec
    Timer(const Duration(milliseconds: 1200), widget.onCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Matches your "Financial Pulse" section
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF004D40), size: 80),
              ),
            ),
            const SizedBox(height: 32),
            const Text("Welcome to the Club!",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Setting up your dashboard...",
                style: TextStyle(color: Colors.white60, fontSize: 16)),
            const SizedBox(height: 40),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white10,
                color: Colors.greenAccent,
                minHeight: 4,
              ),
            )
          ],
        ),
      ),
    );
  }
}
