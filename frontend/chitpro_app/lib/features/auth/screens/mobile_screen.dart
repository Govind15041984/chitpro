import 'package:flutter/material.dart';
import '../../../api/auth_api.dart';
import 'pin_screen.dart';
import 'signup_screen.dart';

class MobileScreen extends StatefulWidget {
  const MobileScreen({super.key});
  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    print("🚀 [3] Set Loading to True. Mobile: ${_mobileController.text}");
    try {
      final exists = await AuthApi.checkMobile(_mobileController.text);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => exists
              ? PinScreen(mobile: _mobileController.text)
              : SignupScreen(mobile: _mobileController.text),
        ),
      );
    } catch (e) {
      print("❌ Error in _continue: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Matches Dashboard background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CHITPRO", style: TextStyle(color: Color(0xFF004D40), letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                const Text("Grow your savings together.", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 40),

                // Floating Input Card Style
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          counterText: "",
                          labelText: "Mobile Number",
                          prefixText: "+91 ",
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF004D40)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (v) => RegExp(r'^[0-9]{10}$').hasMatch(v ?? '') ? null : "Enter 10-digit number",
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40), // Your Deep Green
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
