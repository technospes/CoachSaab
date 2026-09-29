import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import 'app_shell.dart';
import 'auth_screen.dart'; 

class SplashScreen extends StatefulWidget {
  /// Optional override for reading the stored access token.
  ///
  /// Defaults to the real FlutterSecureStorage().read(key: 'access_token')
  /// call. Tests can inject a synchronous/fake implementation here instead
  /// of trying to mock flutter_secure_storage's platform MethodChannel,
  /// which has no native implementation registered in the widget-test VM
  /// and would otherwise hang or throw MissingPluginException.
  final Future<String?> Function()? tokenReader;

  const SplashScreen({super.key, this.tokenReader});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  
  late Animation<double> _bgOpacity;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<double> _text1Opacity;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _bgOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _heroScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.25, 0.6, curve: Curves.easeOutBack)),
    );
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.25, 0.5, curve: Curves.easeOut)),
    );
    _text1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
    );

    _animController.forward().then((_) async {
      final readToken = widget.tokenReader ?? () async {
        const storage = FlutterSecureStorage();
        return storage.read(key: 'access_token');
      };
      final token = await readToken();
      
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('user_id');
      final savedUserName = prefs.getString('user_name');

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        
        if (savedUserId != null && savedUserName != null && token != null) {
          // AUTO-LOGIN: Go straight to Home!
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => AppShell(userName: savedUserName, userId: savedUserId, accessToken: token),
              transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        } else {
          // NO TOKEN: Route to the new Auth Screen
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => const AuthScreen(),
              transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background blur and skeleton overlay
          FadeTransition(
            opacity: _bgOpacity,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1598971639058-fab3c3109a00?q=80&w=600&auto=format&fit=crop',
                      fit: BoxFit.cover,
                    ),
                    CustomPaint(
                      painter: _PushupBackgroundPainter(),
                    ),
                    Container(
                      color: Colors.white.withValues(alpha: 0.75), 
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 🚀 TIGHTENED LAYOUT: Grouped content with balanced spacing
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Hug contents tightly
              children: [
                FadeTransition(
                  opacity: _heroOpacity,
                  child: ScaleTransition(
                    scale: _heroScale,
                    child: SizedBox(
                      height: 250, // Scaled down slightly for better proportions
                      child: Image.asset(
                        'assets/images/Splash_Screen_Icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Controlled gap between image and text
                FadeTransition(
                  opacity: _text1Opacity,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w600, 
                        color: AppColors.textPrimaryLight, 
                        fontFamily: 'Inter',
                      ),
                      children: [
                        TextSpan(text: 'Measure. '),
                        TextSpan(text: 'Correct. ', style: TextStyle(color: AppColors.accent)),
                        TextSpan(text: 'Improve.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PushupBackgroundPainter extends CustomPainter {
  _PushupBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;
    final dotPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    
    final head = Offset(size.width * 0.75, size.height * 0.35);
    final neck = Offset(size.width * 0.65, size.height * 0.40);
    final shoulder = Offset(size.width * 0.55, size.height * 0.45);
    final elbow = Offset(size.width * 0.62, size.height * 0.60);
    final wrist = Offset(size.width * 0.55, size.height * 0.75);
    final hip = Offset(size.width * 0.35, size.height * 0.42);
    final knee = Offset(size.width * 0.15, size.height * 0.50);
    final ankle = Offset(size.width * 0.05, size.height * 0.58);
    
    final f1 = Offset(size.width * 0.58, size.height * 0.78);
    final f2 = Offset(size.width * 0.62, size.height * 0.77);

    final points = [head, neck, shoulder, elbow, wrist, hip, knee, ankle, f1, f2];
    
    canvas.drawLine(head, neck, linePaint);
    canvas.drawLine(neck, shoulder, linePaint);
    canvas.drawLine(shoulder, elbow, linePaint);
    canvas.drawLine(elbow, wrist, linePaint);
    canvas.drawLine(wrist, f1, linePaint);
    canvas.drawLine(wrist, f2, linePaint);
    canvas.drawLine(shoulder, hip, linePaint);
    canvas.drawLine(hip, knee, linePaint);
    canvas.drawLine(knee, ankle, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PushupBackgroundPainter oldDelegate) => false;
}

// ==========================================
// ONBOARDING SCREEN
// ==========================================
class OnboardingScreen extends StatefulWidget {
  final String? initialName; 
  final String userId;       // NEW: Required ID
  final String accessToken;  // NEW: Required Token

  const OnboardingScreen({
    super.key, 
    this.initialName,
    required this.userId,
    required this.accessToken,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _userName = '';
  String _selectedGender = 'Male';
  bool _isLoading = false; 
  
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _userName = widget.initialName!;
    }
    _idleController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _nextPage() async {
    if (_currentPage == 0 && _userName.trim().isEmpty) return;
    
    if (_currentPage == 0) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      setState(() => _isLoading = true);

      try {
        // FIXED: Secure PUT request to update the existing user profile
        final url = Uri.parse('https://coachsaab-api.onrender.com/api/v1/users/${widget.userId}');
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.accessToken}',
          },
          body: jsonEncode({
            'name': _userName.trim(),
            'gender': _selectedGender,
            'goals': [],
          }),
        );

        if (response.statusCode == 200) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', _userName.trim());
          await prefs.remove('conversation_id'); 

          if (!mounted) return;
          
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => AppShell(
                userName: _userName.trim(), 
                userId: widget.userId, 
                accessToken: widget.accessToken
              ),
              transitionsBuilder: (c, anim, a2, child) => FadeTransition(opacity: anim, child: child),
            ),
          );
        } else {
          debugPrint('Failed to complete onboarding: ${response.body}');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('Network error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: false, 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            AnimatedBuilder(
              animation: _idleController,
              builder: (context, child) {
                return SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, -0.05), end: const Offset(0, 0.05)).animate(CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine)),
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentPale,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://api.dicebear.com/9.x/micah/png?seed=Coach&backgroundColor=transparent', 
                        fit: BoxFit.cover
                      ),
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildNamePage(),
                  _buildGenderPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
              child: Column(
                children: [
                  _isLoading 
                      ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
                      : _buildPrimaryButton('Continue', _nextPage, isEnabled: _currentPage == 1 || _userName.trim().isNotEmpty),
                  const SizedBox(height: AppSpacing.lg),
                  _buildProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const Text("What's Your Name?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
          const SizedBox(height: AppSpacing.sm),
          const Text("I'll personalize your experience.", style: TextStyle(fontSize: 15, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 40),
          
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: TextEditingController(text: _userName),
              onChanged: (value) => setState(() => _userName = value),
              textInputAction: TextInputAction.done, 
              onSubmitted: (_) {
                FocusScope.of(context).unfocus(); 
              },
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: const TextStyle(color: AppColors.textSecondaryLight),
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondaryLight),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const Text("What's Your Gender?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
          const SizedBox(height: AppSpacing.sm),
          const Text("This helps me customize your fitness plan better.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppColors.textSecondaryLight)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _genderOption('Male', Icons.man_rounded),
              _genderOption('Female', Icons.woman_rounded),
              _genderOption('Prefer not\nto say', Icons.person_outline_rounded),
            ],
          )
        ],
      ),
    );
  }

  Widget _genderOption(String title, IconData icon) {
    bool isSelected = _selectedGender == title.replaceAll('\n', ' ');
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = title.replaceAll('\n', ' ')),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 105,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentPale : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.accent.withValues(alpha: 0.5) : Colors.grey.shade200, width: 1.5),
          boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
        ),
        child: Stack(
          children: [
            if (isSelected)
              Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, color: AppColors.accent.withValues(alpha: 0.8), size: 18)),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: isSelected ? AppColors.accent : AppColors.textSecondaryLight),
                  const SizedBox(height: AppSpacing.sm),
                  Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.textPrimaryLight : AppColors.textSecondaryLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool isEnabled = true}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isEnabled ? 1.0 : 0.4,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPale,
            foregroundColor: AppColors.textPrimaryLight,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          onPressed: isEnabled ? onPressed : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 6,
          decoration: BoxDecoration(
            color: _currentPage == index ? AppColors.accent : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}