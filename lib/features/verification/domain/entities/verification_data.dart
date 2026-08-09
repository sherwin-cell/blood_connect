class VerificationData {
  final String? idType;
  final String? idImagePath;
  final String? backIdImagePath;
  final String? selfiePath;
  final String? extractedName;
  final String? extractedBirthDate;
  final String? extractedGender;
  final String? idNumber;
  final bool hasDetectedFace;
  final double? faceMatchConfidence;
  final bool? faceMatchPassed;
  final String? verificationProvider;
  final Map<String, dynamic>? arsaRawResponse;

  const VerificationData({
    this.idType,
    this.idImagePath,
    this.backIdImagePath,
    this.selfiePath,
    this.extractedName,
    this.extractedBirthDate,
    this.extractedGender,
    this.idNumber,
    this.hasDetectedFace = false,
    this.faceMatchConfidence,
    this.faceMatchPassed,
    this.verificationProvider,
    this.arsaRawResponse,
  });

  VerificationData copyWith({
    String? idType,
    String? idImagePath,
    String? backIdImagePath,
    String? selfiePath,
    String? extractedName,
    String? extractedBirthDate,
    String? extractedGender,
    String? idNumber,
    bool? hasDetectedFace,
    double? faceMatchConfidence,
    bool? faceMatchPassed,
    String? verificationProvider,
    Map<String, dynamic>? arsaRawResponse,
  }) {
    return VerificationData(
      idType: idType ?? this.idType,
      idImagePath: idImagePath ?? this.idImagePath,
      backIdImagePath: backIdImagePath ?? this.backIdImagePath,
      selfiePath: selfiePath ?? this.selfiePath,
      extractedName: extractedName ?? this.extractedName,
      extractedBirthDate: extractedBirthDate ?? this.extractedBirthDate,
      extractedGender: extractedGender ?? this.extractedGender,
      idNumber: idNumber ?? this.idNumber,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
      faceMatchConfidence: faceMatchConfidence ?? this.faceMatchConfidence,
      faceMatchPassed: faceMatchPassed ?? this.faceMatchPassed,
      verificationProvider: verificationProvider ?? this.verificationProvider,
      arsaRawResponse: arsaRawResponse ?? this.arsaRawResponse,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idType': idType,
      'extractedName': extractedName,
      'extractedBirthDate': extractedBirthDate,
      'extractedGender': extractedGender,
      'idNumber': idNumber,
      'hasDetectedFace': hasDetectedFace,
      'faceMatchConfidence': faceMatchConfidence,
      'faceMatchPassed': faceMatchPassed,
      'verificationProvider': verificationProvider,
    };
  }
}
