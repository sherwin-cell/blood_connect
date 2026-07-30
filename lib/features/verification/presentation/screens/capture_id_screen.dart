import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import '../widgets/camera_overlay.dart';
import 'review_id_screen.dart';

class CaptureIdScreen extends StatefulWidget {
  const CaptureIdScreen({super.key});

  @override
  State<CaptureIdScreen> createState() => _CaptureIdScreenState();
}

class _CaptureIdScreenState extends State<CaptureIdScreen> {
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
      if (cameras.isEmpty) {
        throw Exception('No cameras detected on this device.');
      }

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // Lower res is fine for OCR
        enableAudio: false,
      );

      await _cameraController!.initialize();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to initialize camera: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _captureAndProcessId() async {
    // Prevent multiple rapid clicks or calls on unitialized camera
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Take picture with camera safely
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!await imageFile.exists()) {
        throw Exception('Captured photo could not be saved to disk.');
      }

      if (!mounted) return;

      // 2. Pass image to Provider for OCR processing
      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      final bool success = await provider.processIdCard(imageFile);

      if (!mounted) return;

      // 3. Handle processing result explicitly
      // Inside CaptureIdScreen.dart -> update _captureAndProcessId method:

      if (success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider, // Hand off existing instance to the next route!
              child: const ReviewIdScreen(),
            ),
          ),
        );
      } else {
        _showErrorSnackBar(
          'Could not read ID details. Please align your ID and try again.',
        );
      }
    } on CameraException catch (e) {
      if (mounted) {
        _showErrorSnackBar('Camera error: ${e.description}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error processing ID: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Camera unavailable.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Government ID'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          Positioned.fill(child: CameraPreview(_cameraController!)),

          // 2. Framing Cutout Overlay
          const CameraOverlay(),

          // 3. Instruction Banner
          const Align(
            alignment: Alignment(0, -0.65),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Position your government ID within the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ),

          // 4. Loading Overlay or Capture Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: _isProcessing
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Scanning text with OCR...',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    )
                  : FloatingActionButton.large(
                      onPressed: _isProcessing ? null : _captureAndProcessId,
                      backgroundColor: Colors.redAccent,
                      shape: const CircleBorder(),
                      child: const Icon(
                        Icons.camera_alt,
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
