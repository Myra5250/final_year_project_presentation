import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.forgotPassword(email);

    if (mounted) {
      setState(() => _isLoading = false);

      // Always show success (security best practice — don't confirm if email exists)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If that email exists, a reset code was sent. Check the server console.'),
          backgroundColor: Color(0xFF009639),
          duration: Duration(seconds: 4),
        ),
      );

      if (result['success'] == true) {
        Navigator.pushNamed(
          context,
          '/reset_password',
          arguments: {'email': result['email'] ?? email},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 24),

              // Header icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF009639), Color(0xFF00B84A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF009639).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF009639)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter your registered email address. We\'ll send you a reset code to create a new password.',
                style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
              ),
              const SizedBox(height: 36),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email Address',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Enter your registered email',
                        prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009639),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF009639).withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Send Reset Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back to Login'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF009639)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
