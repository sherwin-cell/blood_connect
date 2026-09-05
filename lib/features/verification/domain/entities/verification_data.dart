class VerificationData {
  final String? idImagePath;
  final String? backIdImagePath;
  final String? selfiePath;
  final String? extractedName;
  final String? extractedBirthDate;
  final String? extractedGender;
  final String? bloodType;
  final String? address;
  final String? phoneNumber;
  final bool hasDetectedFace;
  final double? faceMatchConfidence;
  final bool? faceMatchPassed;
  final String? verificationProvider;

  const VerificationData({
    this.idImagePath,
    this.backIdImagePath,
    this.selfiePath,
    this.extractedName,
    this.extractedBirthDate,
    this.extractedGender,
    this.bloodType,
    this.address,
    this.phoneNumber,
    this.hasDetectedFace = false,
    this.faceMatchConfidence,
    this.faceMatchPassed,
    this.verificationProvider,
  });

  // Update copyWith to exclude idType and idNumber
  VerificationData copyWith({
    String? idImagePath,
    String? backIdImagePath,
    String? selfiePath,
    String? extractedName,
    String? extractedBirthDate,
    String? extractedGender,
    String? bloodType,
    String? address,
    String? phoneNumber,
    bool? hasDetectedFace,
    double? faceMatchConfidence,
    bool? faceMatchPassed,
    String? verificationProvider,
  }) {
    return VerificationData(
      idImagePath: idImagePath ?? this.idImagePath,
      backIdImagePath: backIdImagePath ?? this.backIdImagePath,
      selfiePath: selfiePath ?? this.selfiePath,
      extractedName: extractedName ?? this.extractedName,
      extractedBirthDate: extractedBirthDate ?? this.extractedBirthDate,
      extractedGender: extractedGender ?? this.extractedGender,
      bloodType: bloodType ?? this.bloodType,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      hasDetectedFace: hasDetectedFace ?? this.hasDetectedFace,
      faceMatchConfidence: faceMatchConfidence ?? this.faceMatchConfidence,
      faceMatchPassed: faceMatchPassed ?? this.faceMatchPassed,
      verificationProvider: verificationProvider ?? this.verificationProvider,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'extractedName': extractedName,
      'extractedBirthDate': extractedBirthDate,
      'extractedGender': extractedGender,
      'bloodType': bloodType,
      'address': address,
      'phoneNumber': phoneNumber,
      'faceMatchConfidence': faceMatchConfidence,
      'faceMatchPassed': faceMatchPassed,
      'hasDetectedFace': hasDetectedFace,
    };
  }
}
