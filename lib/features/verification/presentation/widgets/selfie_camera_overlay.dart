import 'package:flutter/material.dart';

class SelfieCameraOverlay extends StatelessWidget {
  final bool isPassed;

  const SelfieCameraOverlay({super.key, this.isPassed = false});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _SelfieOverlayPainter(isPassed: isPassed)),
    );
  }
}

class _SelfieOverlayPainter extends CustomPainter {
  final bool isPassed;

  _SelfieOverlayPainter({required this.isPassed});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.black54;
    final strokePaint = Paint()
      ..color = isPassed ? Colors.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2.3);
    final ovalWidth = size.width * 0.65;
    final ovalHeight = size.height * 0.45;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    final ovalPath = Path()..addOval(ovalRect);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    canvas.drawPath(overlayPath, fillPaint);
    canvas.drawOval(ovalRect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SelfieOverlayPainter oldDelegate) {
    return oldDelegate.isPassed != isPassed;
  }
}
