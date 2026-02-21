import 'package:flutter/material.dart';
import '../../../api/auth_api.dart';
import '../../subscription/data/subscription_api.dart';
import '../../../core/auth_storage.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../subscription/screens/subscription_screen.dart';

class PinScreen extends StatefulWidget {
  final String mobile;
  const PinScreen({super.key, required this.mobile});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await AuthApi.login(widget.mobile, _pinController.text);

      debugPrint("LOGIN TOKEN => $token");

      // 🔥 THIS WAS MISSING — THIS IS THE ROOT CAUSE
      await AuthStorage.instance.saveToken(token);

      final verify = await AuthStorage.instance.getToken();
      debugPrint("TOKEN AFTER LOGIN SAVE => $verify");

      if (verify == null) {
        throw Exception("Token storage failed");
      }

      final sub = await SubscriptionApi.getCurrent();
      debugPrint("SUBSCRIPTION RESPONSE => $sub");

      final status = sub["status"]; // or sub["subscription"]["status"]

      debugPrint("SUBSCRIPTION STATUS => $status");

      if (sub["status"] == "ACTIVE") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionScreen()),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid PIN")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Matches your "Financial Pulse" card
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Secure Login", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Text("Enter PIN for +91 ${widget.mobile}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 50),

              TextFormField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white, fontSize: 30, letterSpacing: 20),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(20)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.greenAccent), borderRadius: BorderRadius.circular(20)),
                ),
                validator: (v) => RegExp(r'^[0-9]{4}$').hasMatch(v ?? '') ? null : "Invalid PIN",
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Unlock Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
