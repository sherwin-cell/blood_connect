import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/request_id_verification_data.dart';
import '../provider/request_id_verification_provider.dart';
import '../widgets/id_camera_overlay.dart';
import 'review_id_screen.dart';

class CaptureBackIdScreen extends StatefulWidget {
  const CaptureBackIdScreen({super.key});

  @override
  State<CaptureBackIdScreen> createState() => _CaptureBackIdScreenState();
}

class _CaptureBackIdScreenState extends State<CaptureBackIdScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isInitializing = false;
  bool _isProcessing = false;
  bool _isDisposingCamera = false;
  bool _shouldRenderPreview = true;
  int _initializationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_cameraController != null) {
        unawaited(_disposeCamera());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_cameraController == null &&
          !_isDisposingCamera &&
          !_isInitializing) {
        unawaited(_initializeCamera());
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_isDisposingCamera) return;

    _isDisposingCamera = true;
    final CameraController? controller = _cameraController;
    _cameraController = null;
    _shouldRenderPreview = false;

    if (mounted && !_isProcessing) {
      setState(() {
        _isInitializing = true;
        _shouldRenderPreview = false;
      });
    }

    try {
      if (controller != null && controller.value.isInitialized) {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('CaptureBackIdScreen dispose error: $e');
    } finally {
      _isDisposingCamera = false;

      if (mounted && !_isProcessing) {
        setState(() {
          _isInitializing = false;
          _shouldRenderPreview = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted || _isDisposingCamera || _isInitializing) return;

    final int generation = ++_initializationGeneration;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _shouldRenderPreview = false;
      });
    }

    try {
      final cameras = await availableCameras();

      if (!mounted ||
          _isDisposingCamera ||
          generation != _initializationGeneration) {
        return;
      }

      if (cameras.isEmpty) {
        throw Exception('No cameras detected.');
      }

      final cameraDescription = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        cameraDescription,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      if (!mounted ||
          _isDisposingCamera ||
          generation != _initializationGeneration) {
        await controller.dispose();
        return;
      }

      final CameraController? previousController = _cameraController;

      _cameraController = controller;
      _shouldRenderPreview = false;

      try {
        await controller.initialize();
      } catch (e) {
        if (_cameraController == controller) {
          _cameraController = null;
        }
        rethrow;
      }

      if (!mounted ||
          _isDisposingCamera ||
          generation != _initializationGeneration) {
        final activeController = _cameraController;

        if (activeController == controller) {
          _cameraController = null;
        }

        _shouldRenderPreview = false;

        await controller.dispose();
        return;
      }

      if (previousController != null && previousController != controller) {
        try {
          if (previousController.value.isInitialized) {
            await previousController.dispose();
          }
        } catch (e) {
          debugPrint(
            'CaptureBackIdScreen previous controller dispose error: $e',
          );
        }
      }

      _shouldRenderPreview = true;
    } catch (e) {
      _cameraController = null;
      _shouldRenderPreview = false;

      if (mounted) {
        _showErrorSnackBar('Failed to initialize camera: $e');
      }
    } finally {
      if (mounted &&
          !_isDisposingCamera &&
          generation == _initializationGeneration) {
        setState(() {
          _isInitializing = false;
          _shouldRenderPreview =
              _cameraController != null &&
              _cameraController!.value.isInitialized;
        });
      }
    }
  }

  Future<void> _captureAndProcessBackId() async {
    if (_isProcessing ||
        _isDisposingCamera ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    if (mounted) {
      setState(() => _isProcessing = true);
    }

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!await imageFile.exists()) {
        throw Exception('Captured photo could not be saved to disk.');
      }

      if (!mounted) return;

      final provider = Provider.of<RequestIdVerificationProvider>(
        context,
        listen: false,
      );

      final bool success = await provider.processBackIdCard(imageFile);

      if (!mounted) return;

      if (success) {
        final CameraController? controller = _cameraController;

        _cameraController = null;
        _shouldRenderPreview = false;

        if (mounted) {
          setState(() => _shouldRenderPreview = false);
        }

        if (controller != null && controller.value.isInitialized) {
          try {
            await controller.dispose();
          } catch (e) {
            debugPrint('CaptureBackIdScreen capture dispose error: $e');
          }
        }

        if (!mounted) return;

        final RequestIdVerificationData? result = await navigator
            .push<RequestIdVerificationData>(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const ReviewIdScreen(),
                ),
              ),
            );

        if (!mounted) return;

        if (result != null) {
          Navigator.of(context).pop<RequestIdVerificationData>(result);
        }
      } else {
        _showErrorSnackBar('Could not process back of ID. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger?.showSnackBar(
          SnackBar(
            content: Text('Error capturing back ID: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
    WidgetsBinding.instance.removeObserver(this);

    final CameraController? controller = _cameraController;
    _cameraController = null;

    if (controller != null && controller.value.isInitialized) {
      unawaited(_disposeCamera());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _isDisposingCamera || !_shouldRenderPreview) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
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
          Positioned.fill(child: CameraPreview(controller)),
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
