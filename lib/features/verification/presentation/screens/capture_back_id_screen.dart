import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import '../widgets/id_camera_overlay.dart';
import 'face_verification_instructions_screen.dart';

class CaptureBackIdScreen extends StatefulWidget {
  const CaptureBackIdScreen({super.key});

  @override
  State<CaptureBackIdScreen> createState() => _CaptureBackIdScreenState();
}

class _CaptureBackIdScreenState extends State<CaptureBackIdScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No cameras detected.');

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to initialize camera: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _captureAndProcessBackId() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!await imageFile.exists()) {
        throw Exception('Captured photo could not be saved to disk.');
      }

      if (!mounted) return;

      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      final bool success = await provider.processBackIdCard(imageFile);

      if (!mounted) return;

      if (success) {
        // Detach preview surface texture before pausing & navigating
        setState(() => _isNavigatingAway = true);
        await _cameraController?.pausePreview().catchError((_) {});

        if (!mounted) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: const FaceVerificationInstructionsScreen(),
            ),
          ),
        );

        // Resume camera surface if popped back to this screen
        if (mounted) {
          setState(() => _isNavigatingAway = false);
          await _cameraController?.resumePreview().catchError((_) {});
        }
      } else {
        _showErrorSnackBar('Could not process back of ID. Please try again.');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error capturing back ID: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
    WidgetsBinding.instance.removeObserver(this);
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
        title: const Text('Capture Back of ID'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Render preview ONLY when initialized and active on screen
          if (!_isNavigatingAway &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!))
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          const CameraOverlay(),

          const Align(
            alignment: Alignment(0, -0.65),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Position the BACK of your government ID within the frame',
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
                          'Processing back side...',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    )
                  : FloatingActionButton.large(
                      onPressed: _isProcessing
                          ? null
                          : _captureAndProcessBackId,
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
