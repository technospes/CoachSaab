import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  PosePainter({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    // 🎨 PRODUCTION UI: Sleek, minimalist lines
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 // ✅ Reduced from 4.0 for a cleaner look
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2DD4CF).withValues(alpha: 0.85);

    final jointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final jointOuterPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 // ✅ Reduced from 2.0 to match the thinner skeleton
      ..color = const Color(0xFF2DD4CF);

    for (final pose in poses) {
      Offset translate(PoseLandmark landmark) {
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
        final PoseLandmark? joint1 = pose.landmarks[PoseLandmarkType.values.firstWhere((e) => e.name == type1)];
        final PoseLandmark? joint2 = pose.landmarks[PoseLandmarkType.values.firstWhere((e) => e.name == type2)];
        if (joint1 == null || joint2 == null) return;
        
        if (joint1.likelihood > 0.6 && joint2.likelihood > 0.6) {
          canvas.drawLine(translate(joint1), translate(joint2), linePaint);
        }
      }

      // Draw Skeleton Lines
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

      for (final landmark in pose.landmarks.values) {
        if (landmark.likelihood > 0.6) {
          final offset = translate(landmark);
          canvas.drawCircle(offset, 3.0, jointPaint);       // ✅ Reduced from 4.0
          canvas.drawCircle(offset, 4.5, jointOuterPaint);  // ✅ Reduced from 6.0
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}

double translateX(double x, Size canvasSize, Size imageSize, InputImageRotation rotation, CameraLensDirection cameraLensDirection) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x * canvasSize.width / (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation270deg:
      return canvasSize.width - x * canvasSize.width / (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      switch (cameraLensDirection) {
        case CameraLensDirection.front:
          return canvasSize.width - x * canvasSize.width / imageSize.width;
        default:
          return x * canvasSize.width / imageSize.width;
      }
  }
}

double translateY(double y, Size canvasSize, Size imageSize, InputImageRotation rotation) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y * canvasSize.height / (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvasSize.height / imageSize.height;
  }
}