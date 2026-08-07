class VerificationData {
  final String? idImagePath;
  final String? backIdImagePath;
  final String? selfiePath;
  final String? idType;
  final String? idNumber;
  final String? extractedName;
  final String? extractedBirthDate;
  final String? extractedGender;
  final bool hasDetectedFace;

  const VerificationData({
    this.idImagePath,
    this.backIdImagePath,
    this.selfiePath,
    this.idType,
    this.idNumber,
    this.extractedName,
    this.extractedBirthDate,
    this.extractedGender,
    this.hasDetectedFace = false,
  });

  VerificationData copyWith({
    String? idImagePath,
    String? backIdImagePath,
    String? selfiePath,
    String? idType,
    String? idNumber,
    String? extractedName,
    String? extractedBirthDate,
    String? extractedGender,
    bool? hasDetectedFace,
  }) {
    return VerificationData(
      idImagePath: idImagePath ?? this.idImagePath,
      backIdImagePath: backIdImagePath ?? this.backIdImagePath,
      selfiePath: selfiePath ?? this.selfiePath,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      extractedName: extractedName ?? this.extractedName,
      extractedBirthDate: extractedBirthDate ?? this.extractedBirthDate,
      extractedGender: extractedGender ?? this.extractedGender,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
    );
  }
}
