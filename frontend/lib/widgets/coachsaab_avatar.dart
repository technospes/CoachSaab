import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class CoachSaabAvatar extends StatefulWidget {
  final VoidCallback onTap;
  const CoachSaabAvatar({super.key, required this.onTap});

  @override
  State<CoachSaabAvatar> createState() => _CoachSaabAvatarState();
}

class _CoachSaabAvatarState extends State<CoachSaabAvatar> with WidgetsBindingObserver {
  final Flutter3DController _controller = Flutter3DController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.pauseAnimation();
    } else if (state == AppLifecycleState.resumed) {
      _controller.playAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 55, // ⬇️ Shrunk from 84 to 55
      height: 55, // ⬇️ Shrunk from 84 to 55
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A2B33),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2B33).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          //   HIGH-RES CROP TRICK
          // Renders a crisp 180x180 canvas, but only shows the 64x64 clipped face
          OverflowBox(
            maxWidth: 180,
            maxHeight: 180,
            alignment: const Alignment(0.0, -0.91), // Shifts the crisp canvas up to focus on the head
            child: Flutter3DViewer(
              src: 'assets/models/coachsaab.glb',
              controller: _controller,
              enableTouch: false,
              activeGestureInterceptor: true,
              progressBarColor: Colors.transparent,
              onLoad: (String modelAddress) {
                _controller.playAnimation();
              },
            ),
          ),
          // Transparent clickable overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                splashColor: Colors.white12,
                highlightColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}