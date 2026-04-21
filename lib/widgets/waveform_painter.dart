import 'package:flutter/material.dart';

/// CustomPainter for real-time audio waveform visualization.
/// Renders a smooth waveform from audio samples with gradient fill.
class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final double strokeWidth;

  WaveformPainter({
    required this.samples,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw center line
    final centerLinePaint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );

    // Build waveform path
    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (samples.length - 1);
    final amplitude = size.height * 0.4;

    for (int i = 0; i < samples.length; i++) {
      final x = i * stepX;
      final y = centerY - (samples[i] * amplitude);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, centerY);
        fillPath.lineTo(x, y);
      } else {
        // Use quadratic bezier for smooth curves
        final prevX = (i - 1) * stepX;
        final prevY = centerY - (samples[i - 1] * amplitude);
        final midX = (prevX + x) / 2;

        path.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
        fillPath.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);

        if (i == samples.length - 1) {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
    }

    // Close fill path
    fillPath.lineTo(size.width, centerY);
    fillPath.close();

    // Draw gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw waveform line
    canvas.drawPath(path, paint);

    // Draw mirrored waveform (bottom half)
    final mirrorPath = Path();
    final mirrorFillPath = Path();

    for (int i = 0; i < samples.length; i++) {
      final x = i * stepX;
      final y = centerY + (samples[i] * amplitude);

      if (i == 0) {
        mirrorPath.moveTo(x, y);
        mirrorFillPath.moveTo(x, centerY);
        mirrorFillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = centerY + (samples[i - 1] * amplitude);
        final midX = (prevX + x) / 2;

        mirrorPath.quadraticBezierTo(prevX, prevY, midX, (prevY + y) / 2);
        mirrorFillPath.quadraticBezierTo(
            prevX, prevY, midX, (prevY + y) / 2);

        if (i == samples.length - 1) {
          mirrorPath.lineTo(x, y);
          mirrorFillPath.lineTo(x, y);
        }
      }
    }

    mirrorFillPath.lineTo(size.width, centerY);
    mirrorFillPath.close();

    final mirrorFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(mirrorFillPath, mirrorFillPaint);

    final mirrorPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = strokeWidth * 0.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mirrorPath, mirrorPaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}
