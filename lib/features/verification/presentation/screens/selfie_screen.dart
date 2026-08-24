import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'review_all_screen.dart';

enum LivenessStep {
  lookStraight,
  turnLeft,
  turnRight,
  smile,
  countingDown,
  completed,
}

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

  // Progress from 0.0 to 1.0 for the tick ring
  double _progressValue = 0.0;
  bool _isInsideOval = false;
  int _countdownSeconds = 3;

  LivenessStep _currentStep = LivenessStep.lookStraight;

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
    if (cameraController == null || !cameraController.value.isInitialized)
      return;

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
        _currentStep == LivenessStep.countingDown ||
        _currentStep == LivenessStep.completed) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        _evaluateFlow(faces.first, image);
      } else {
        if (mounted && _isInsideOval) {
          setState(() {
            _isInsideOval = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing liveness frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _evaluateFlow(Face face, CameraImage image) {
    final double? headY = face.headEulerAngleY;
    final double? smileProb = face.smilingProbability;

    final Rect boundingBox = face.boundingBox;
    final double imgWidth = image.width.toDouble();
    final double imgHeight = image.height.toDouble();

    final double faceWidthRatio = boundingBox.width / imgWidth;
    final double faceHeightRatio = boundingBox.height / imgHeight;

    bool isInside =
        faceWidthRatio >= 0.20 &&
        faceWidthRatio <= 0.80 &&
        faceHeightRatio >= 0.20 &&
        faceHeightRatio <= 0.80;

    if (isInside != _isInsideOval) {
      setState(() {
        _isInsideOval = isInside;
      });
    }

    if (!isInside) return;

    switch (_currentStep) {
      case LivenessStep.lookStraight:
        if (headY == null || headY.abs() < 18) {
          setState(() {
            _progressValue = 0.25;
            _currentStep = LivenessStep.turnLeft;
          });
        }
        break;

      case LivenessStep.turnLeft:
        if (headY != null && headY > 15) {
          setState(() {
            _progressValue = 0.55;
            _currentStep = LivenessStep.turnRight;
          });
        }
        break;

      case LivenessStep.turnRight:
        if (headY != null && headY < -15) {
          setState(() {
            _progressValue = 0.85;
            _currentStep = LivenessStep.smile;
          });
        }
        break;

      case LivenessStep.smile:
        if (smileProb != null && smileProb > 0.40) {
          setState(() {
            _progressValue = 1.0;
            _currentStep = LivenessStep.countingDown;
          });
          _startAutoCaptureCountdown();
        }
        break;

      case LivenessStep.countingDown:
      case LivenessStep.completed:
        break;
    }
  }

  Future<void> _startAutoCaptureCountdown() async {
    await _cameraController?.stopImageStream();

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdownSeconds = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    setState(() => _currentStep = LivenessStep.completed);
    await _completeLivenessCheck();
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
        setState(() {
          _currentStep = LivenessStep.lookStraight;
          _progressValue = 0.0;
          _countdownSeconds = 3;
        });
        _cameraController?.startImageStream(_processCameraFrame);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face check failed. Please remain inside the oval.'),
            backgroundColor: Colors.redAccent,
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
          _currentStep = LivenessStep.lookStraight;
          _progressValue = 0.0;
          _countdownSeconds = 3;
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

    final bool isCompleted = _currentStep == LivenessStep.completed;
    final bool isCounting = _currentStep == LivenessStep.countingDown;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Cancel Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  alignment: Alignment.centerLeft,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blueAccent, fontSize: 16),
                ),
              ),
              const Spacer(flex: 1),

              // Center Oval Camera Frame & Segmented Ticks / Countdown Overlay
              Center(
                child: SizedBox(
                  width: 280,
                  height: 350,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Oval Hollow Camera Mask Container
                      Container(
                        width: 210,
                        height: 280,
                        decoration: const BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(
                            Radius.elliptical(210, 280),
                          ),
                        ),
                        child: ClipOval(
                          child:
                              (!_isNavigatingAway &&
                                  _cameraController != null &&
                                  _cameraController!.value.isInitialized)
                              ? OverflowBox(
                                  alignment: Alignment.center,
                                  child: CameraPreview(_cameraController!),
                                )
                              : Container(color: Colors.black),
                        ),
                      ),

                      // Segmented Tick Oval Ring Painter
                      CustomPaint(
                        size: const Size(280, 350),
                        painter: FaceIDOvalTickRingPainter(
                          progress: _progressValue,
                          isComplete: isCompleted || isCounting,
                          isInsideOval: _isInsideOval,
                        ),
                      ),

                      // 3, 2, 1 Countdown overlay in the center
                      if (isCounting)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_countdownSeconds',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Instruction Text
              Center(
                child: Text(
                  isCompleted
                      ? 'First Face ID scan complete.'
                      : (isCounting
                            ? 'Taking picture in $_countdownSeconds...'
                            : (!_isInsideOval
                                  ? 'Align face inside the oval (WAIT)'
                                  : _getInstructionText())),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isInsideOval ? Colors.amberAccent : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Bottom Action Area
              if (isCompleted)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _completeLivenessCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                const Center(
                  child: Text(
                    'Accessibility Options',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getInstructionText() {
    switch (_currentStep) {
      case LivenessStep.lookStraight:
        return 'Look straight into the camera.';
      case LivenessStep.turnLeft:
        return 'Slowly turn your head to the LEFT.';
      case LivenessStep.turnRight:
        return 'Slowly turn your head to the RIGHT.';
      case LivenessStep.smile:
        return 'Hold steady and SMILE.';
      case LivenessStep.countingDown:
        return 'Get ready...';
      case LivenessStep.completed:
        return 'First Face ID scan complete.';
    }
  }
}

/// Custom painter to draw segmented tick marks along an Oval path
class FaceIDOvalTickRingPainter extends CustomPainter {
  final double progress;
  final bool isComplete;
  final bool isInsideOval;

  FaceIDOvalTickRingPainter({
    required this.progress,
    required this.isComplete,
    required this.isInsideOval,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double radiusX = 110.0;
    const double radiusY = 145.0;
    const totalTicks = 60;

    final paint = Paint()
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final double angle = (i * 2 * math.pi / totalTicks) - (math.pi / 2);
      final double tickProgress = i / totalTicks;

      if (isComplete) {
        paint.color = Colors.greenAccent;
      } else if (!isInsideOval) {
        paint.color = Colors.amber.withOpacity(0.4);
      } else if (tickProgress <= progress) {
        paint.color = Colors.greenAccent;
      } else {
        paint.color = Colors.grey.withOpacity(0.35);
      }

      final double cosA = math.cos(angle);
      final double sinA = math.sin(angle);

      final startX = center.dx + (radiusX - 8) * cosA;
      final startY = center.dy + (radiusY - 8) * sinA;
      final endX = center.dx + (radiusX + 2) * cosA;
      final endY = center.dy + (radiusY + 2) * sinA;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant FaceIDOvalTickRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isComplete != isComplete ||
        oldDelegate.isInsideOval != isInsideOval;
  }
}
