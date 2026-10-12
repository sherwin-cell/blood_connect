class RequestIdVerificationData {
  final String? idType;
  final String? frontIdImage;
  final String? backIdImage;
  final String? validationStatus;
  final DateTime? submittedAt;

  const RequestIdVerificationData({
    this.idType,
    this.frontIdImage,
    this.backIdImage,
    this.validationStatus,
    this.submittedAt,
  });

  static bool isApprovedStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'approved' || normalized == 'verified';
  }

  static bool requiresIdCapture(String? status) {
    return !isApprovedStatus(status);
  }

  // FIXED: Now properly checks for idType, frontIdImage, AND backIdImage!
  bool get isComplete =>
      (idType != null && idType!.trim().isNotEmpty) &&
      (frontIdImage != null && frontIdImage!.isNotEmpty) &&
      (backIdImage != null && backIdImage!.isNotEmpty);

  RequestIdVerificationData copyWith({
    String? idType,
    String? frontIdImage,
    String? backIdImage,
    String? validationStatus,
    DateTime? submittedAt,
  }) {
    return RequestIdVerificationData(
      idType: idType ?? this.idType,
      frontIdImage: frontIdImage ?? this.frontIdImage,
      backIdImage: backIdImage ?? this.backIdImage,
      validationStatus: validationStatus ?? this.validationStatus,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap({
    required String frontIdImageUrl,
    String? backIdImageUrl,
  }) {
    return {
      'idType': idType,
      'frontIdImageUrl': frontIdImageUrl,
      'backIdImageUrl': backIdImageUrl,
      'validationStatus': validationStatus ?? 'pending',
      'submittedAt':
          submittedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}
