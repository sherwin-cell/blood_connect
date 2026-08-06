class VerificationData {
  final String? idType;
  final String? idImagePath;
  final String? backIdImagePath; // <--- Add this field
  final String? selfiePath;
  final String? extractedName;
  final String? idNumber;
  final bool hasDetectedFace;

  const VerificationData({
    this.idType,
    this.idImagePath,
    this.backIdImagePath,
    this.selfiePath,
    this.extractedName,
    this.idNumber,
    this.hasDetectedFace = false,
  });

  VerificationData copyWith({
    String? idType,
    String? idImagePath,
    String? backIdImagePath,
    String? selfiePath,
    String? extractedName,
    String? idNumber,
    bool? hasDetectedFace,
  }) {
    return VerificationData(
      idType: idType ?? this.idType,
      idImagePath: idImagePath ?? this.idImagePath,
      backIdImagePath: backIdImagePath ?? this.backIdImagePath,
      selfiePath: selfiePath ?? this.selfiePath,
      extractedName: extractedName ?? this.extractedName,
      idNumber: idNumber ?? this.idNumber,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
    );
  }
}
