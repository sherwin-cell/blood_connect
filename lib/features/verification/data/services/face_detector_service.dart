import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FaceDetectorService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.05,
    ),
  );

  Future<bool> hasValidFace(File imageFile) async {
    final faces = await _detectFaces(imageFile);
    return faces.isNotEmpty;
  }

  Future<int> countFaces(File imageFile) async {
    final faces = await _detectFaces(imageFile);
    return faces.length;
  }

  /// Crops the largest detected face (with padding) into a JPEG temp file.
  ///
  /// Used so ARSA receives a clear face crop from a full government-ID photo,
  /// which often fails with HTTP 400 "Could not detect faces in one or both images".
  Future<File?> cropPrimaryFace(
    File imageFile, {
    double paddingRatio = 0.45,
  }) async {
    final faces = await _detectFaces(imageFile);
    if (faces.isEmpty) {
      debugPrint('FaceDetectorService: no face to crop in ${imageFile.path}');
      return null;
    }

    if (faces.length > 1) {
      debugPrint(
        'FaceDetectorService: ${faces.length} faces found; using largest.',
      );
    }

    Face primary = faces.first;
    double largestArea = primary.boundingBox.width * primary.boundingBox.height;
    for (final face in faces.skip(1)) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area > largestArea) {
        largestArea = area;
        primary = face;
      }
    }

    final bytes = await imageFile.readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      debugPrint('FaceDetectorService: failed to decode image for crop.');
      return null;
    }

    // Match ML Kit's upright coordinate space (camera JPEGs often have EXIF rotation).
    decoded = img.bakeOrientation(decoded);

    final box = primary.boundingBox;
    final padX = box.width * paddingRatio;
    final padY = box.height * paddingRatio;

    final left = math.max(0, (box.left - padX).floor());
    final top = math.max(0, (box.top - padY).floor());
    final right = math.min(decoded.width, (box.right + padX).ceil());
    final bottom = math.min(decoded.height, (box.bottom + padY).ceil());

    final width = math.max(1, right - left);
    final height = math.max(1, bottom - top);

    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: width,
      height: height,
    );

    final jpg = img.encodeJpg(cropped, quality: 92);
    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'arsa_face_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(jpg, flush: true);

    debugPrint(
      'FaceDetectorService: cropped face -> $outPath '
      '(${jpg.length} bytes, ${width}x$height)',
    );
    return outFile;
  }

  Future<List<Face>> _detectFaces(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return _faceDetector.processImage(inputImage);
  }

  void dispose() {
    _faceDetector.close();
  }
}
