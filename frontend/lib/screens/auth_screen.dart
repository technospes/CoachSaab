import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'app_shell.dart';
import 'otp_screen.dart'; 
import 'splash_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize(
        serverClientId: '22550512486-srcidaokmte8frmkbkrpd8chmm5g15b4.apps.googleusercontent.com',
      );

      final GoogleSignInAccount account = await googleSignIn.authenticate(scopeHint: ['email']);
      final GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) throw Exception('Failed to get ID token');

      final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String accessToken = data['access_token'];
        final user = data['user'];
        final bool onboardingCompleted = data['onboarding_completed'] ?? false;
        
        if (_rememberMe) {
          await _storage.write(key: 'access_token', value: accessToken);
        } else {
          await _storage.delete(key: 'access_token');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user['user_id']);
        await prefs.setString('user_name', user['name']);

        if (!mounted) return;

        if (onboardingCompleted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppShell(
            userName: user['name'], userId: user['user_id'], accessToken: accessToken,
          )));
        } else {
          // NEW: Pass the ID and Token to the Onboarding Screen!
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen(
            initialName: user['name'],
            userId: user['user_id'],
            accessToken: accessToken,
          )));
        }
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['detail'] ?? 'Google Auth failed'), backgroundColor: AppColors.error));
        await googleSignIn.signOut();
      }
    } catch (e) {
      if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
        return; 
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign-In failed.'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final url = Uri.parse(_isLogin 
        ? 'https://coachsaab-api.onrender.com/api/v1/auth/login' 
        : 'https://coachsaab-api.onrender.com/api/v1/auth/register');

    final Map<String, dynamic> body = _isLogin 
        ? {'email': _emailCtrl.text.trim(), 'password': _passwordCtrl.text}
        : {'name': _nameCtrl.text.trim(), 'email': _emailCtrl.text.trim(), 'password': _passwordCtrl.text};

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (!_isLogin) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(email: _emailCtrl.text.trim())));
          return;
        }

        final String accessToken = data['access_token'];
        final user = data['user'];
        
        if (_rememberMe) {
          await _storage.write(key: 'access_token', value: accessToken);
        } else {
          await _storage.delete(key: 'access_token');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user['user_id']);
        await prefs.setString('user_name', user['name']);

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppShell(
          userName: user['name'], userId: user['user_id'], accessToken: accessToken,
        )));

      } else {
        final data = jsonDecode(response.body);
        if (data['detail'] == 'unverified_email') {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(email: _emailCtrl.text.trim())));
          return;
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['detail'] ?? 'Authentication failed'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error. Please try again.'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/icons/Login_Avatar.png',
                      height: 80, 
                      width: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _isLogin ? 'Welcome Back 👋' : 'Create your account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (!_isLogin)
                    _buildTextField(
                      controller: _nameCtrl,
                      label: 'Name',
                      icon: Icons.person_outline_rounded,
                      validator: (val) => val!.isEmpty ? 'Name is required' : null,
                    ),

                  _buildTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val!.isEmpty) return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: (val) => val!.length < 6 ? 'Password must be at least 6 characters' : null,
                  ),

                  if (!_isLogin)
                    _buildTextField(
                      controller: _confirmPasswordCtrl,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (val) => val != _passwordCtrl.text ? 'Passwords do not match' : null,
                    ),

                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.accent,
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      ),
                      const Text('Remember me', style: TextStyle(color: AppColors.textSecondaryLight)),
                      const Spacer(),
                      if (_isLogin)
                        TextButton(
                          onPressed: () {},
                          child: const Text('Forgot Password?', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _submitAuth,
                        child: Text(_isLogin ? 'Log In' : 'Create Account', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),

                  const SizedBox(height: AppSpacing.md),
                  
                  if (!_isLoading) ...[
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OR', style: TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _handleGoogleSignIn,
                      icon: Image.network(
                        'https://developers.google.com/identity/images/g-logo.png',
                        height: 24,
                        width: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.g_mobiledata_rounded, 
                            color: Colors.blue, 
                            size: 32,
                          );
                        },
                      ),
                      label: const Text('Continue with Google', style: TextStyle(color: AppColors.textPrimaryLight, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                  
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In",
                      style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.textSecondaryLight),
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        ),
      ),
    );
  }
}