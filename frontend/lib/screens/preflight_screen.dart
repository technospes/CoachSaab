import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import '../presentation/camera_view.dart'; // Imports your existing CV pipeline!
import '../tracking/session_config.dart';

class PreFlightScreen extends StatefulWidget {
  final String activityName;
  final SessionConfig sessionConfig;
  
  const PreFlightScreen({
    super.key, 
    required this.activityName, 
    required this.sessionConfig
  });

  @override
  State<PreFlightScreen> createState() => _PreFlightScreenState();
}

class _PreFlightScreenState extends State<PreFlightScreen> with SingleTickerProviderStateMixin {
  int _counter = 3;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for the numbers
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutBack));
    _pulseController.forward();

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_counter > 1) {
        setState(() {
          _counter--;
          _pulseController.reset();
          _pulseController.forward();
        });
      } else {
        _timer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CameraView(
              activityName: widget.activityName,
              sessionConfig: widget.sessionConfig, 
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark, // Match the cinematic train mode
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Top Header
            Positioned(
              top: AppSpacing.xl,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text('Get Ready For', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 16)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(widget.activityName, style: const TextStyle(color: AppColors.accent, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Central Countdown
            Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Text(
                      '$_counter',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 140,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }
              ),
            ),
            
            // Bottom Info
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: const [
                  Icon(Icons.center_focus_strong_rounded, color: AppColors.textSecondaryDark, size: 32),
                  SizedBox(height: AppSpacing.md),
                  Text('Step back so your whole body is visible.', style: TextStyle(color: AppColors.textSecondaryDark)),
                ],
              ),
            ),

            // Back Button (If they want to cancel before it starts)
            Positioned(
              top: AppSpacing.md,
              left: AppSpacing.md,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }
}