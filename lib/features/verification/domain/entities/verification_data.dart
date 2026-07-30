class VerificationData {
  final String? idImagePath;
  final String? selfiePath;
  final String? idType;
  final String? extractedName;
  final String? idNumber;
  final bool hasDetectedFace;

  const VerificationData({
    this.idImagePath,
    this.selfiePath,
    this.idType,
    this.extractedName,
    this.idNumber,
    this.hasDetectedFace = false,
  });

  VerificationData copyWith({
    String? idImagePath,
    String? selfiePath,
    String? idType,
    String? extractedName,
    String? idNumber,
    bool? hasDetectedFace,
  }) {
    return VerificationData(
      idImagePath: idImagePath ?? this.idImagePath,
      selfiePath: selfiePath ?? this.selfiePath,
      idType: idType ?? this.idType,
      extractedName: extractedName ?? this.extractedName,
      idNumber: idNumber ?? this.idNumber,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
    );
  }
}
