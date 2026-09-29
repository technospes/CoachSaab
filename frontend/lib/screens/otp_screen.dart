import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'splash_screen.dart'; // To access OnboardingScreen

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  int _cooldownSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/auth/verify-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // 1. Securely save the JWT access token
        const storage = FlutterSecureStorage();
        await storage.write(key: 'access_token', value: data['access_token']);

        // 2. Save public user info
        final user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user['user_id']);
        await prefs.setString('user_name', user['name']);

        if (!mounted) return;

        // 3. Route to Onboarding!
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => OnboardingScreen(
              initialName: user['name'], // Pass the name so it pre-fills!
              userId: user['user_id'],   // Pass the required ID
              accessToken: data['access_token'], // Pass the required Token
            ),
            transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        // Handle backend errors (expired, wrong code, etc.)
        final errorMsg = data['detail'] ?? 'Verification failed. Please try again.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your connection.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/auth/resend-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (response.statusCode == 200) {
        _startCooldown();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification code has been sent!'), backgroundColor: AppColors.success),
        );
      } else {
        final data = jsonDecode(response.body);
        final errorMsg = data['detail'] ?? 'Failed to resend code.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Please check your connection.'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obfuscate the email for privacy (e.g., a***@gmail.com)
    final emailParts = widget.email.split('@');
    final obfuscatedEmail = emailParts.length == 2 
        ? '${emailParts[0].substring(0, 1)}***@${emailParts[1]}' 
        : widget.email;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        // Wrapping the Column in a SingleChildScrollView prevents overflow when the keyboard appears.
        child: SingleChildScrollView( 
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.accentPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded, size: 48, color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.xl),
              
              const Text(
                'Verify your email',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: AppSpacing.md),
              
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondaryLight, height: 1.5),
                  children: [
                    const TextSpan(text: "We've sent a 6-digit verification code to\n"),
                    TextSpan(text: obfuscatedEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),

              // OTP Input Field
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 16, color: AppColors.textPrimaryLight),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: "", // Hides the "0/6" character counter
                    border: InputBorder.none,
                    hintText: "••••••",
                    hintStyle: TextStyle(color: Colors.black12, letterSpacing: 16),
                  ),
                  onChanged: (val) {
                    if (val.length == 6) {
                      FocusScope.of(context).unfocus(); // Auto-dismiss keyboard when 6 digits entered
                    }
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Verify Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _verifyOtp,
                        child: const Text('Verify Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),

              const SizedBox(height: AppSpacing.xl),

              // Resend Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive it? ", style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 15)),
                  TextButton(
                    onPressed: _cooldownSeconds > 0 ? null : _resendOtp,
                    child: Text(
                      _cooldownSeconds > 0 ? 'Resend in ${_cooldownSeconds}s' : 'Resend code',
                      style: TextStyle(
                        color: _cooldownSeconds > 0 ? AppColors.textSecondaryLight : AppColors.accent, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 15
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl), // Add a little padding at the bottom for safety
            ],
          ),
        ),
      ),
    );
  }
}