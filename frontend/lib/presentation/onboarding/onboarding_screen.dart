import 'package:flutter/material.dart';

/// TEMPORARY STUB.
///
/// You didn't ask for the onboarding ("What's Your Name?" / "What's Your
/// Gender?") screens in this request — only the splash screen. This stub
/// exists purely so `splash_screen.dart` has a real navigation target and
/// compiles/runs standalone.
///
/// Replace this file's contents with the actual onboarding flow (mockup
/// panels 2 and 3: name entry, then gender selection, each with the
/// avatar bubble and progress dots) when you're ready to build that —
/// splash_screen.dart's import and navigation call won't need to change,
/// since this class name and file path are what it already points to.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('OnboardingScreen — replace with the real flow'),
      ),
    );
  }
}