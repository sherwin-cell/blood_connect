import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'review_all_screen.dart';
import '../widgets/selfie_camera_overlay.dart';

enum LivenessStep { moveCloser, turnLeft, turnRight, smile, completed }

class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  late FaceDetector _faceDetector;

  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isNavigatingAway = false;
  bool _isCountingDown = false;
  int _countdownSeconds = 3;

  LivenessStep _currentStep = LivenessStep.moveCloser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDetector();
    _initializeCamera();
  }

  void _initDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
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
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraController!.startImageStream(_processCameraFrame);
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

  Future<void> _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame ||
        _isNavigatingAway ||
        _isCountingDown ||
        _currentStep == LivenessStep.completed) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        _evaluateLiveness(faces.first);
      }
    } catch (e) {
      debugPrint('Error processing liveness frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _evaluateLiveness(Face face) {
    final double? headY = face.headEulerAngleY;
    final double? smileProb = face.smilingProbability;

    final double screenWidth = MediaQuery.of(context).size.width;
    final Rect boundingBox = face.boundingBox;
    final double faceWidth = boundingBox.width;
    final double faceRatio = faceWidth / screenWidth;

    switch (_currentStep) {
      case LivenessStep.moveCloser:
        // Adjusted threshold to 0.32 so it effortlessly fits your oval overlay guide
        if (faceRatio >= 0.32 && (headY == null || headY.abs() < 15)) {
          _advanceStep(LivenessStep.turnLeft);
        }
        break;

      case LivenessStep.turnLeft:
        if (headY != null && headY > 20) {
          _advanceStep(LivenessStep.turnRight);
        }
        break;

      case LivenessStep.turnRight:
        if (headY != null && headY < -20) {
          _advanceStep(LivenessStep.smile);
        }
        break;

      case LivenessStep.smile:
        if (smileProb != null && smileProb > 0.60 && !_isCountingDown) {
          _advanceStep(LivenessStep.completed);
          _startAutoCaptureCountdown();
        }
        break;

      case LivenessStep.completed:
        break;
    }
  }

  void _advanceStep(LivenessStep step) {
    if (mounted) {
      setState(() => _currentStep = step);
    }
  }

  Future<void> _startAutoCaptureCountdown() async {
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 3;
    });

    await _cameraController?.stopImageStream();

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdownSeconds = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() => _isCountingDown = false);
      await _completeLivenessCheck();
    }
  }

  Future<void> _completeLivenessCheck() async {
    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!mounted) return;

      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      final hasFace = await provider.processSelfie(imageFile);

      if (!mounted) return;

      if (!hasFace) {
        setState(() => _currentStep = LivenessStep.moveCloser);
        _cameraController?.startImageStream(_processCameraFrame);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ??
                  'Liveness check failed. Please try again.',
            ),
            backgroundColor: Colors.amber[900],
          ),
        );
        return;
      }

      setState(() => _isNavigatingAway = true);
      await _cameraController?.pausePreview().catchError((_) {});

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const ReviewAllScreen(),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isNavigatingAway = false;
          _currentStep = LivenessStep.moveCloser;
        });
        await _cameraController?.resumePreview().catchError((_) {});
        _cameraController?.startImageStream(_processCameraFrame);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Liveness execution error: $e')));
      }
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation:
            InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceDetector.close();
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
        title: const Text('Liveness Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (!_isNavigatingAway &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

          _buildStepIndicators(),

          SelfieCameraOverlay(isPassed: _currentStep == LivenessStep.completed),

          if (_isCountingDown)
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Container(
                  key: ValueKey<int>(_countdownSeconds),
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_countdownSeconds',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          _buildInstructionBadge(),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Positioned(
      top: 20,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stepChip(LivenessStep.moveCloser, 'Closer'),
          _stepChip(LivenessStep.turnLeft, 'Turn Left'),
          _stepChip(LivenessStep.turnRight, 'Turn Right'),
          _stepChip(LivenessStep.smile, 'Smile'),
        ],
      ),
    );
  }

  Widget _stepChip(LivenessStep step, String label) {
    final bool isDone = _currentStep.index > step.index;
    final bool isCurrent = _currentStep == step;

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: isDone
              ? Colors.green
              : (isCurrent ? Colors.redAccent : Colors.grey[800]),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${step.index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.white : Colors.white54,
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBadge() {
    String text = '';
    IconData icon = Icons.face;

    switch (_currentStep) {
      case LivenessStep.moveCloser:
        text = 'Move closer to fill the frame';
        icon = Icons.zoom_in;
        break;
      case LivenessStep.turnLeft:
        text = 'Slowly turn your head LEFT';
        icon = Icons.arrow_back;
        break;
      case LivenessStep.turnRight:
        text = 'Slowly turn your head RIGHT';
        icon = Icons.arrow_forward;
        break;
      case LivenessStep.smile:
        text = 'Hold position and SMILE';
        icon = Icons.sentiment_very_satisfied;
        break;
      case LivenessStep.completed:
        text = 'Verification Complete!';
        icon = Icons.check_circle;
        break;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.redAccent, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
