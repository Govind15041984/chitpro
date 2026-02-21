import 'package:flutter/material.dart';
import '../../../api/auth_api.dart';
import '../../subscription/data/subscription_api.dart';
import '../../../core/auth_storage.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../subscription/screens/subscription_screen.dart';

class SignupScreen extends StatefulWidget {
  final String mobile;
  const SignupScreen({super.key, required this.mobile});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  // Logic remains identical to your original code
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. This now creates the user AND the FREE subscription on the Backend
      final token = await AuthApi.register(
        _nameController.text.trim(),
        widget.mobile,
        _pinController.text,
      );

      // 2. Save the token
      await AuthStorage.instance.saveToken(token);

      // 3. REMOVE THIS LINE BELOW (This is what causes the 404)
      // await SubscriptionApi.activate("FREE");

      // 4. Just fetch the current status to confirm
      final sub = await SubscriptionApi.getCurrent();

      if (!mounted) return;

      // 5. Navigate straight to Dashboard
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen())
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Dashboard background color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Create Account",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text("Setting up profile for +91 ${widget.mobile}",
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),

              // Form Container (White Card style)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        hintText: "Enter your legal name",
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (v) => v == null || v.length < 3 ? "Enter valid name" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: "Create Security PIN",
                        hintText: "4-Digit PIN",
                        counterText: "",
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF004D40)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (v) => RegExp(r'^[0-9]{4}$').hasMatch(v ?? '') ? null : "Invalid PIN",
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Start My Free Plan",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  "By creating an account, you agree to our Terms.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}