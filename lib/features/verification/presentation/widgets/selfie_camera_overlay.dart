import 'package:flutter/material.dart';

class SelfieCameraOverlay extends StatelessWidget {
  final bool isAligned;
  final bool isPassed;

  const SelfieCameraOverlay({
    super.key,
    this.isAligned = false,
    this.isPassed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _SelfieOverlayPainter(
          isAligned: isAligned,
          isPassed: isPassed,
        ),
      ),
    );
  }
}

class _SelfieOverlayPainter extends CustomPainter {
  final bool isAligned;
  final bool isPassed;

  const _SelfieOverlayPainter({
    required this.isAligned,
    required this.isPassed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Darkens everything outside the face area.
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.55);

    // Determine the border state.
    Color borderColor;

    if (isPassed) {
      borderColor = Colors.greenAccent;
    } else if (isAligned) {
      borderColor = Colors.greenAccent;
    } else {
      borderColor = Colors.white;
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Face oval position.
    final center = Offset(size.width / 2, size.height * 0.38);

    // Face oval size.
    final ovalWidth = size.width * 0.68;
    final ovalHeight = size.height * 0.52;

    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Create the oval cutout.
    final ovalPath = Path()..addOval(ovalRect);

    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Remove the oval from the dark overlay.
    final overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      ovalPath,
    );

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw the face guide.
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelfieOverlayPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.isPassed != isPassed;
  }
}
