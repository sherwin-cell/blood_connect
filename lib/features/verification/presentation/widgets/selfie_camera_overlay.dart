import 'package:flutter/material.dart';

class SelfieCameraOverlay extends StatelessWidget {
  final bool isAligned;
  final bool isPassed;
  final int? countdownValue;
  final bool isReviewing;
  final bool isProcessing;
  final Widget? child;

  const SelfieCameraOverlay({
    super.key,
    required this.isAligned,
    required this.isPassed,
    this.countdownValue,
    this.isReviewing = false,
    this.isProcessing = false,
    this.child,
  });

  static Rect getOvalRect(Size size) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final ovalWidth = size.width * 0.72;
    final ovalHeight = size.height * 0.50;
    return Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final ovalRect = getOvalRect(size);

          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. Dark backdrop mask with oval cutout & perfectly aligned border
              CustomPaint(
                size: size,
                painter: _SelfieOverlayPainter(
                  isAligned: isAligned,
                  isPassed: isPassed,
                ),
              ),

              // 2. Camera Preview or Captured Photo clipped precisely to the oval
              if (child != null)
                Positioned(
                  left: ovalRect.left,
                  top: ovalRect.top,
                  width: ovalRect.width,
                  height: ovalRect.height,
                  child: ClipOval(child: child!),
                ),

              // 3. Countdown overlay badge inside the oval center
              if (countdownValue != null &&
                  countdownValue! > 0 &&
                  !isReviewing &&
                  !isProcessing)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$countdownValue',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // 4. Processing spinner overlay when verifying the photo
              if (isProcessing)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.greenAccent,
                  ),
                ),

              // 5. Success checkmark badge when scan finishes (only before review/processing)
              if (isPassed &&
                  countdownValue == null &&
                  !isReviewing &&
                  !isProcessing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
            ],
          );
        },
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
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.75);

    Color borderColor;
    if (isPassed) {
      borderColor = Colors.greenAccent;
    } else if (isAligned) {
      borderColor = Colors.blueAccent;
    } else {
      borderColor = Colors.white70;
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final ovalRect = SelfieCameraOverlay.getOvalRect(size);
    final ovalPath = Path()..addOval(ovalRect);
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final overlayPath = Path.combine(
      PathOperation.difference,
      screenPath,
      ovalPath,
    );

    canvas.drawPath(overlayPath, overlayPaint);
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelfieOverlayPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.isPassed != isPassed;
  }
}
