/// The selfie captured on the device, before it is sent to the backend.
///
/// The verification result itself lives on users/{uid} (faceVerified and the
/// faceVerification map), written only by the backend.
class FaceVerificationData {
  final String? selfiePath;

  /// On-device pre-check found a face (usability only, not verification).
  final bool hasDetectedFace;

  const FaceVerificationData({this.selfiePath, this.hasDetectedFace = false});

  FaceVerificationData copyWith({String? selfiePath, bool? hasDetectedFace}) {
    return FaceVerificationData(
      selfiePath: selfiePath ?? this.selfiePath,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
    );
  }
}
