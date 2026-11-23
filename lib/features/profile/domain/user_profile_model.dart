import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';
import 'notification_preferences.dart';

class UserProfile {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final String? gender;
  final DateTime? birthDate;
  final String bloodType;
  final String? province;
  final String? municipality;
  final String? barangay;
  final String? purok;
  final String? nationality;

  /// Profile picture chosen by the user (Cloudinary URL).
  final String? photoUrl;

  /// Verification selfie, used as the avatar until a photo is chosen.
  final String? selfieImageUrl;

  final NotificationPreferences notificationPreferences;

  /// Account identity verification: the backend matched the selfie with the
  /// ID, or a PRC admin approved the account. Read-only for the app.
  final bool faceVerified;

  /// `faceVerification.result` written by the backend or a PRC admin:
  /// 'verified', 'failed', 'approved_by_admin' or 'rejected_by_admin'.
  final String? faceVerificationResult;

  /// The last face check did not pass and PRC has not approved the account.
  bool get faceVerificationFailed =>
      !faceVerified &&
      (faceVerificationResult == FaceVerificationResult.failed ||
          faceVerificationResult == FaceVerificationResult.rejectedByAdmin);

  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    this.fullName = '',
    required this.phoneNumber,
    this.gender,
    this.birthDate,
    required this.bloodType,
    this.province,
    this.municipality,
    this.barangay,
    this.purok,
    this.nationality,
    this.photoUrl,
    this.selfieImageUrl,
    this.notificationPreferences = const NotificationPreferences(),
    this.faceVerified = false,
    this.faceVerificationResult,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isVerified => faceVerified;

  /// Member code shown on cards, e.g. BC-IB1WA.
  String get memberCode {
    final id = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (id.isEmpty) return 'BC-00000';
    return 'BC-${id.length >= 5 ? id.substring(0, 5) : id.padRight(5, '0')}';
  }

  /// The picture to show for this user: their photo, else the selfie.
  String? get avatarUrl {
    for (final url in [photoUrl, selfieImageUrl]) {
      if (url != null && url.trim().isNotEmpty) return url;
    }
    return null;
  }

  /// "Purok 3, Burabod, Sorsogon City, Sorsogon" from the parts present.
  String get formattedAddress {
    final purokText = purok?.trim() ?? '';
    final parts = [
      if (purokText.isNotEmpty)
        purokText.toLowerCase().startsWith('purok')
            ? purokText
            : 'Purok $purokText',
      for (final part in [barangay, municipality, province])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    ];
    return parts.join(', ');
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic field) {
      if (field is Timestamp) return field.toDate();
      if (field is String && field.isNotEmpty) {
        return DateTime.tryParse(field);
      }
      return null;
    }

    // Only the backend (or a PRC admin) sets faceVerified; there is no
    // fallback to the old client-reported verificationStatus.
    final faceVerified = json['faceVerified'] == true;
    final faceVerification = json['faceVerification'];
    final faceVerificationResult = faceVerification is Map
        ? faceVerification['result'] as String?
        : null;

    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName:
          (json['fullName'] ?? json['fullname'] ?? json['name'] ?? '')
              as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      gender: json['gender'] as String?,
      // Complete Profile and Edit Profile store `birthday` (YYYY-MM-DD).
      birthDate: parseDate(json['birthDate'] ?? json['birthday']),
      bloodType: json['bloodType'] as String? ?? '',
      province: json['province'] as String?,
      municipality: json['municipality'] as String?,
      barangay: json['barangay'] as String?,
      purok: json['purok'] as String?,
      nationality: json['nationality'] as String?,
      photoUrl: json['photoUrl'] as String?,
      selfieImageUrl: faceVerification is Map
          ? faceVerification['selfieImageUrl'] as String?
          : null,
      notificationPreferences: NotificationPreferences.fromMap(
        json[NotificationPreferences.field],
      ),
      faceVerified: faceVerified,
      faceVerificationResult: faceVerificationResult,
      profileCompleted:
          (json['profileCompleted'] ?? json['isProfileComplete']) as bool? ??
          false,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      'bloodType': bloodType,
      if (province != null) 'province': province,
      if (municipality != null) 'municipality': municipality,
      if (barangay != null) 'barangay': barangay,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'faceVerified': faceVerified,
      'profileCompleted': profileCompleted,
    };
  }
}
