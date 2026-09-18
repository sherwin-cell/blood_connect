import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';
import 'face_verification_result_screen.dart';
import '../widgets/selfie_camera_overlay.dart';

enum LivenessStep {
  lookStraight,
  turnLeft,
  turnRight,
  smile,
  countingDown,
  completed,
}

class SelfieScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const SelfieScreen({super.key, this.onComplete});

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

  bool _isInsideOval = false;
  int _countdownSeconds = 3;
  LivenessStep _currentStep = LivenessStep.lookStraight;

  // Photo review state tracking properties
  File? _capturedSelfie;
  bool _isReviewingPhoto = false;
  bool _isProcessingPhoto = false;

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
      if (!_isReviewingPhoto && !_isProcessingPhoto) {
        _initializeCamera();
      }
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
        _isReviewingPhoto ||
        _isProcessingPhoto ||
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
        faceWidthRatio >= 0.15 &&
        faceWidthRatio <= 0.85 &&
        faceHeightRatio >= 0.15 &&
        faceHeightRatio <= 0.85;

    if (isInside != _isInsideOval) {
      setState(() {
        _isInsideOval = isInside;
      });
    }

    if (!isInside) return;

    switch (_currentStep) {
      case LivenessStep.lookStraight:
        if (headY == null || headY.abs() < 18) {
          setState(() => _currentStep = LivenessStep.turnLeft);
        }
        break;

      case LivenessStep.turnLeft:
        if (headY != null && headY > 15) {
          setState(() => _currentStep = LivenessStep.turnRight);
        }
        break;

      case LivenessStep.turnRight:
        if (headY != null && headY < -15) {
          setState(() => _currentStep = LivenessStep.smile);
        }
        break;

      case LivenessStep.smile:
        if (smileProb != null && smileProb > 0.35) {
          setState(() => _currentStep = LivenessStep.countingDown);
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
    await _capturePhoto();
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      if (!mounted) return;
      setState(() {
        _capturedSelfie = imageFile;
        _isReviewingPhoto = true;
      });

      final oldController = _cameraController;
      _cameraController = null;
      await oldController?.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to capture photo: $e')));
        _onRetakePressed();
      }
    }
  }

  void _onRetakePressed() async {
    setState(() {
      _capturedSelfie = null;
      _isReviewingPhoto = false;
      _isProcessingPhoto = false;
      _currentStep = LivenessStep.lookStraight;
      _countdownSeconds = 3;
      _isInitializing = true;
    });
    await _initializeCamera();
  }

  Future<void> _onContinuePressed() async {
    if (_capturedSelfie == null) return;

    setState(() {
      _isReviewingPhoto = false;
      _isProcessingPhoto = true;
    });

    try {
      final provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      final hasFace = await provider.processSelfie(_capturedSelfie!);
      if (!mounted) return;

      if (!hasFace) {
        setState(() => _isProcessingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid face detected in photo. Please retake.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _onRetakePressed();
        return;
      }

      setState(() => _isNavigatingAway = true);
      final submitted = await provider.submitFaceVerification();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: FaceVerificationResultScreen(
              success: submitted,
              onComplete: widget.onComplete,
            ),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isNavigatingAway = false;
          _isProcessingPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPhoto = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Face verification error: $e')));
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
        child: Stack(
          children: [
            // Reusable overlay manages mask cutout and conditional inner view
            // Replace the entire Center/Stack block in your SelfieScreen build method with this:
            SelfieCameraOverlay(
              isAligned: _isInsideOval,
              isPassed: isCompleted || isCounting,
              countdownValue: isCounting ? _countdownSeconds : null,
              isReviewing: _isReviewingPhoto,
              isProcessing: _isProcessingPhoto,
              child:
                  (_isReviewingPhoto || _isProcessingPhoto) &&
                      _capturedSelfie != null
                  ? Image.file(_capturedSelfie!, fit: BoxFit.cover)
                  : (!_isNavigatingAway &&
                        _cameraController != null &&
                        _cameraController!.value.isInitialized)
                  ? OverflowBox(
                      alignment: Alignment.center,
                      child: CameraPreview(_cameraController!),
                    )
                  : Container(color: Colors.black),
            ),

            // Foreground Layout Elements
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const Spacer(),

                  // Bottom Status/Instruction Text
                  Center(
                    child: Text(
                      _isReviewingPhoto
                          ? 'Is this photo okay?\nMake sure your face is clear and visible.'
                          : (_isProcessingPhoto
                                ? 'Processing your photo...\nPlease wait while we verify your face.'
                                : (isCompleted
                                      ? 'Scan complete.'
                                      : (isCounting
                                            ? 'Taking picture in $_countdownSeconds...'
                                            : (!_isInsideOval
                                                  ? 'Align face inside the oval (WAIT)'
                                                  : _getInstructionText())))),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            !_isInsideOval &&
                                !_isReviewingPhoto &&
                                !_isProcessingPhoto
                            ? Colors.amberAccent
                            : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bottom Action Buttons Area
                  if (_isReviewingPhoto)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _onRetakePressed,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.blueAccent,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Retake',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _onContinuePressed,
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
                          ),
                        ),
                      ],
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
          ],
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
        return 'Scan complete.';
    }
  }
}
