import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'verification_pending_screen.dart';

class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      // Select the front-facing camera for the selfie
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Lower res is fine for ML face check
        enableAudio: false,
      );

      await _cameraController!.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize selfie camera: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _captureAndSubmit() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() => _isProcessing = true);

    try {
      // 1. Capture the image file
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!mounted) return;

      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      // 2. Run local ML Kit Face Detection (Validation Step)
      final hasFace = await provider.processSelfie(imageFile);

      if (!mounted) return;

      // UX Feedback: Face Check failed
      if (!hasFace) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ??
                  'Face check failed. Please look clearly at the camera.',
            ),
            backgroundColor: Colors.amber[900],
          ),
        );
        return;
      }

      // 3. User passed face check -> Submit all data to Firebase/Cloudinary
      final String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception("User must be authenticated to submit.");
      }

      setState(() => _isProcessing = true);
      final submissionSuccess = await provider.submit(userId);

      if (!mounted) return;

      if (submissionSuccess) {
        // 4. Navigate to Pending Screen upon final success
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
          (route) => false, // Clears the entire navigation stack
        );
      } else {
        // Firebase Submission failed (e.g. network issue)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Submission failed.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Camera unavailable.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Selfie'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Camera Viewfinder (Scaled to center)
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),

          // 2. Instruction Banner
          const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 40, 32, 0),
              child: Text(
                'Hold the phone still and look directly at the camera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
            ),
          ),

          // 3. Circle Framing Overlay (Custom Painted)
          Positioned.fill(child: CustomPaint(painter: FaceOverlayPainter())),

          // 4. Processing Overlay or Capture Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: _isProcessing
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.redAccent),
                          SizedBox(height: 16),
                          Text(
                            'Processing and Uploading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Face Validation • Cloudinary Upload • Firestore Submission',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  : FloatingActionButton.large(
                      onPressed: _captureAndSubmit,
                      backgroundColor: Colors.redAccent,
                      shape: const CircleBorder(),
                      child: const Icon(
                        Icons.camera_front,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter to overlay a darkened background with a circular cutout
/// guiding the user where to position their face.
class FaceOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final circlePath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(
            size.width / 2,
            size.height / 2.3,
          ), // Slightly above absolute center
          radius: size.width * 0.35, // Adjust size as needed
        ),
      );

    // Combine paths to create the punched-out effect
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      circlePath,
    );

    // Draw the translucent black background
    canvas.drawPath(overlayPath, paint);

    // Draw the white circular border
    canvas.drawOval(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2.3),
        radius: size.width * 0.35,
      ),
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
