import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AiCoachApp());
}

// ==========================================
// 1. GLOBAL DESIGN SYSTEM
// ==========================================
class AppColors {
  static const backgroundLight = Color(0xFFF9FAFB);
  static const surfaceLight = Colors.white;
  static const textPrimaryLight = Color(0xFF111827);
  static const textSecondaryLight = Color(0xFF6B7280);

  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const textPrimaryDark = Colors.white;
  static const textSecondaryDark = Color(0xFFA0A0A0);

  static const accent = Color(0xFF00B4D8);
  static const accentPale = Color(0xFFE0F7FA);
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const smallControl = 12.0;
  static const card = 20.0;
  static const heroCard = 24.0;
  static const fab = 16.0;
  static const bottomSheet = 24.0;
  static const input = 16.0;
}

class AiCoachApp extends StatelessWidget {
  const AiCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoachSaab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        useMaterial3: true,
        
        // ADDED 1: Global Apple-style slide transitions for navigation
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      
      //   ADDED 2: Injects the premium scroll physics into every screen automatically
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: PremiumScrollBehavior(),
          child: child!,
        );
      },
      
      home: const SplashScreen(),
    );
  }
}

//   ADDED 3: The custom scroll behavior class (placed at the bottom of the file)
// ==========================================
// 2. GLOBAL UX BEHAVIORS
// ==========================================
class PremiumScrollBehavior extends ScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Replaces the harsh Android "stretch/glow" with a fluid, elastic bounce globally
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}