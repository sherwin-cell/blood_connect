class FaceVerificationData {
  final String? selfiePath;
  final bool hasDetectedFace;
  final double? faceMatchConfidence;
  final bool? faceMatchPassed;
  final String? verificationProvider;
  final String? verificationResult;
  final DateTime? verifiedAt;

  const FaceVerificationData({
    this.selfiePath,
    this.hasDetectedFace = false,
    this.faceMatchConfidence,
    this.faceMatchPassed,
    this.verificationProvider,
    this.verificationResult,
    this.verifiedAt,
  });

  bool get isVerified =>
      verificationResult == 'verified' && hasDetectedFace;

  FaceVerificationData copyWith({
    String? selfiePath,
    bool? hasDetectedFace,
    double? faceMatchConfidence,
    bool? faceMatchPassed,
    String? verificationProvider,
    String? verificationResult,
    DateTime? verifiedAt,
  }) {
    return FaceVerificationData(
      selfiePath: selfiePath ?? this.selfiePath,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
      faceMatchConfidence: faceMatchConfidence ?? this.faceMatchConfidence,
      faceMatchPassed: faceMatchPassed ?? this.faceMatchPassed,
      verificationProvider: verificationProvider ?? this.verificationProvider,
      verificationResult: verificationResult ?? this.verificationResult,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}
