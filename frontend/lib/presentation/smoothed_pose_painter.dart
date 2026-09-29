import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_painter.dart' show translateX, translateY;
import '../domain/unified_landmark.dart';

/// Draws the body skeleton from an already-smoothed landmark map (as
/// produced by PoseSmoother.smooth), rather than from raw ML Kit `Pose`
/// output the way PosePainter does.
///
/// WHY A SEPARATE PAINTER RATHER THAN MODIFYING PosePainter:
/// PosePainter's contract (`List<Pose> poses`) is ML Kit's own result
/// type, and its translateX/translateY functions are written specifically
/// against that type's rotation/mirroring conventions. Smoothed data is a
/// different shape (a `Map` of `PoseLandmarkType` to `UnifiedLandmark`,
/// already in normalized 0-1 space with no separate rotation metadata
/// attached). Rather than overload PosePainter with two input shapes,
/// this mirrors HandPainter's existing pattern in this file: a small,
/// focused painter per data source, composited as separate CustomPaint
/// layers.
///
/// COORDINATE SPACE NOTE: PoseSmoother filters the SAME x/y values
/// LandmarkFusion.fromPose would have produced (ML Kit's normalized,
/// already-portrait-corrected pose coordinates — see PosePainter's
/// translateX/translateY, which do the rotation/mirror correction before
/// these values are used elsewhere in the pipeline). This painter
/// intentionally reuses PosePainter's translateX/translateY functions on
/// the smoothed values so the smoothed skeleton lines up with exactly
/// where PosePainter would have drawn the raw one — same rotation/mirror
/// handling, just fed filtered input.
class SmoothedPosePainter extends CustomPainter {
  SmoothedPosePainter({
    required this.landmarks,
    required this.absoluteImageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  final Map<String, UnifiedLandmark> landmarks;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.greenAccent;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white;

    Offset? translate(String type) {
      final landmark = landmarks[type];
      if (landmark == null) return null;
      final double x = translateX(
        landmark.x,
        size,
        absoluteImageSize,
        rotation,
        cameraLensDirection,
      );
      final double y = translateY(
        landmark.y,
        size,
        absoluteImageSize,
        rotation,
      );
      return Offset(x, y);
    }

    void paintLine(String type1, String type2) {
      final joint1 = landmarks[type1];
      final joint2 = landmarks[type2];
      if (joint1 == null || joint2 == null) return;
      if (joint1.confidence > 0.5 && joint2.confidence > 0.5) {
        final p1 = translate(type1);
        final p2 = translate(type2);
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    landmarks.forEach((type, landmark) {
      if (landmark.confidence > 0.5) {
        final p = translate(type);
        if (p != null) canvas.drawCircle(p, 5.0, dotPaint);
      }
    });

    paintLine('leftShoulder', 'rightShoulder');
    paintLine('leftHip', 'rightHip');
    paintLine('leftShoulder', 'leftHip');
    paintLine('rightShoulder', 'rightHip');

    paintLine('leftHip', 'leftKnee');
    paintLine('leftKnee', 'leftAnkle');

    paintLine('rightHip', 'rightKnee');
    paintLine('rightKnee', 'rightAnkle');

    paintLine('leftShoulder', 'leftElbow');
    paintLine('leftElbow', 'leftWrist');

    paintLine('rightShoulder', 'rightElbow');
    paintLine('rightElbow', 'rightWrist');
  }

  @override
  bool shouldRepaint(covariant SmoothedPosePainter oldDelegate) {
    //   Performance optimization: Only repaint if the core data changes
    return oldDelegate.landmarks != landmarks || 
           oldDelegate.absoluteImageSize != absoluteImageSize ||
           oldDelegate.rotation != rotation;
  }
}