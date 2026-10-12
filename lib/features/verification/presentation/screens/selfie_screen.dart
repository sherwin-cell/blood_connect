import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // ============================================================
  // FACE DETECTOR
  // ============================================================

  void _initDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

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

  // ============================================================
  // CAMERA INITIALIZATION
  // ============================================================

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera available.');
      }

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

      if (!mounted) {
        return;
      }

      _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize selfie camera: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  // ============================================================
  // CAMERA FRAME PROCESSING
  // ============================================================

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

      if (inputImage == null) {
        return;
      }

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

  // ============================================================
  // LIVENESS EVALUATION
  // ============================================================

  void _evaluateFlow(Face face, CameraImage image) {
    final double? headY = face.headEulerAngleY;
    final double? smileProb = face.smilingProbability;

    final Rect boundingBox = face.boundingBox;

    final double imgWidth = image.width.toDouble();
    final double imgHeight = image.height.toDouble();

    final double faceWidthRatio = boundingBox.width / imgWidth;

    final double faceHeightRatio = boundingBox.height / imgHeight;

    final bool isInside =
        faceWidthRatio >= 0.15 &&
        faceWidthRatio <= 0.85 &&
        faceHeightRatio >= 0.15 &&
        faceHeightRatio <= 0.85;

    if (isInside != _isInsideOval) {
      setState(() {
        _isInsideOval = isInside;
      });
    }

    if (!isInside) {
      return;
    }

    switch (_currentStep) {
      case LivenessStep.lookStraight:
        if (headY == null || headY.abs() < 18) {
          setState(() {
            _currentStep = LivenessStep.turnLeft;
          });
        }
        break;

      case LivenessStep.turnLeft:
        if (headY != null && headY > 15) {
          setState(() {
            _currentStep = LivenessStep.turnRight;
          });
        }
        break;

      case LivenessStep.turnRight:
        if (headY != null && headY < -15) {
          setState(() {
            _currentStep = LivenessStep.smile;
          });
        }
        break;

      case LivenessStep.smile:
        if (smileProb != null && smileProb > 0.35) {
          setState(() {
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

  // ============================================================
  // AUTO CAPTURE COUNTDOWN
  // ============================================================

  Future<void> _startAutoCaptureCountdown() async {
    await _cameraController?.stopImageStream();

    for (int i = 3; i > 0; i--) {
      if (!mounted) {
        return;
      }

      setState(() {
        _countdownSeconds = i;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentStep = LivenessStep.completed;
    });

    await _capturePhoto();
  }

  // ============================================================
  // CAPTURE SELFIE
  // ============================================================

  Future<void> _capturePhoto() async {
    try {
      final XFile image = await _cameraController!.takePicture();

      final File imageFile = File(image.path);

      if (!mounted) {
        return;
      }

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

  // ============================================================
  // RETAKE PHOTO
  // ============================================================

  Future<void> _onRetakePressed() async {
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

  // ============================================================
  // CONTINUE AFTER SELFIE REVIEW
  // ============================================================

  Future<void> _onContinuePressed() async {
    if (_capturedSelfie == null) {
      return;
    }

    setState(() {
      _isReviewingPhoto = false;
      _isProcessingPhoto = true;
    });

    try {
      final VerificationProvider provider = Provider.of<VerificationProvider>(
        context,
        listen: false,
      );

      // ----------------------------------------------------------
      // PROCESS SELFIE
      // ----------------------------------------------------------

      final bool hasFace = await provider.processSelfie(_capturedSelfie!);

      if (!mounted) {
        return;
      }

      if (!hasFace) {
        setState(() {
          _isProcessingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid face detected in photo. Please retake.'),
            backgroundColor: Colors.redAccent,
          ),
        );

        await _onRetakePressed();

        return;
      }

      // ----------------------------------------------------------
      // SUBMIT FACE VERIFICATION
      // ----------------------------------------------------------

      setState(() {
        _isNavigatingAway = true;
      });

      final bool submitted = await provider.submitFaceVerification();

      if (!mounted) {
        return;
      }

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        debugPrint('SELFIE: No authenticated Firebase user.');

        Navigator.of(context).popUntil((route) => route.isFirst);

        return;
      }

      // ----------------------------------------------------------
      // OPEN FACE VERIFICATION RESULT
      // ----------------------------------------------------------

      debugPrint('');
      debugPrint('====================================================');
      debugPrint('SELFIE: Opening FaceVerificationResultScreen');
      debugPrint('SELFIE: Face verification submitted = $submitted');
      debugPrint('====================================================');

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: FaceVerificationResultScreen(success: submitted),
          ),
        ),
      );

      // ----------------------------------------------------------
      // FACE RESULT SCREEN CLOSED
      // ----------------------------------------------------------

      if (!mounted) {
        return;
      }

      debugPrint('');
      debugPrint('====================================================');
      debugPrint('SELFIE: FaceVerificationResultScreen closed.');
      debugPrint('SELFIE: Verification flow finished.');
      debugPrint('====================================================');

      // Face verification + ID verification are both finished.
      // Close SelfieScreen and return to HomeTabView.
      if (mounted) {
        debugPrint('SELFIE: Closing SelfieScreen.');
        debugPrint('SELFIE: Returning to HomeTabView.');
        Navigator.of(context).pop();
      }

      // ----------------------------------------------------------
      // IMPORTANT
      // ----------------------------------------------------------
      //
      // Do NOT push another screen here.
      //
      // FaceVerificationResultScreen handles the ID flow.
      //
      // Once the ID flow is submitted, the result screen closes
      // and this route will be removed by the parent Home flow.
      //
      // ----------------------------------------------------------
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('====================================================');
      debugPrint('SELFIE: FACE VERIFICATION ERROR');
      debugPrint('====================================================');
      debugPrint('SELFIE ERROR: $e');
      debugPrint('SELFIE STACK TRACE:');
      debugPrint('$stackTrace');

      if (mounted) {
        setState(() {
          _isProcessingPhoto = false;
          _isNavigatingAway = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Face verification error: $e')));
      }
    }
  }

  // ============================================================
  // CONVERT CAMERA IMAGE
  // ============================================================

  InputImage? _convertToInputImage(CameraImage image) {
    if (_cameraController == null) {
      return null;
    }

    final CameraDescription camera = _cameraController!.description;

    final int sensorOrientation = camera.sensorOrientation;

    final InputImageFormat? format = InputImageFormatValue.fromRawValue(
      image.format.raw,
    );

    if (format == null) {
      return null;
    }

    final WriteBuffer allBytes = WriteBuffer();

    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final Uint8List bytes = allBytes.done().buffer.asUint8List();

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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cameraController?.dispose();

    _faceDetector.close();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

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
            // ====================================================
            // CAMERA / OVERLAY
            // ====================================================
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

            // ====================================================
            // FOREGROUND UI
            // ====================================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------------------------------------
                  // CANCEL
                  // ------------------------------------------------
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
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

                  // ------------------------------------------------
                  // STATUS / INSTRUCTIONS
                  // ------------------------------------------------
                  Center(
                    child: Text(
                      _isReviewingPhoto
                          ? 'Is this photo okay?\n'
                                'Make sure your face is clear and visible.'
                          : _isProcessingPhoto
                          ? 'Processing your photo...\n'
                                'Please wait while we verify your face.'
                          : isCompleted
                          ? 'Scan complete.'
                          : isCounting
                          ? 'Taking picture in '
                                '$_countdownSeconds...'
                          : !_isInsideOval
                          ? 'Align face inside the oval (WAIT)'
                          : _getInstructionText(),
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

                  // ------------------------------------------------
                  // ACTION BUTTONS
                  // ------------------------------------------------
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

  // ============================================================
  // LIVENESS INSTRUCTION
  // ============================================================

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
