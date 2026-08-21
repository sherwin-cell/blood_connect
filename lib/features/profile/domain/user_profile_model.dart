import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? photoUrl;

  /// 'unverified' | 'pending' | 'approved' | 'rejected'
  final String verificationStatus;

  /// Admin's review notes — written on both approve & reject.
  final String? adminNotes;

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
    this.photoUrl,
    this.verificationStatus = 'unverified',
    this.adminNotes,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isVerified => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';

  factory UserProfile.fromFirestore(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic field) {
      if (field is Timestamp) return field.toDate();
      if (field is String && field.isNotEmpty) {
        return DateTime.tryParse(field);
      }
      return null;
    }

    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName:
          (json['fullName'] ?? json['fullname'] ?? json['name'] ?? '')
              as String,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      gender: json['gender'] as String?,
      birthDate: parseDate(json['birthDate']),
      bloodType: json['bloodType'] as String? ?? '',
      province: json['province'] as String?,
      municipality: json['municipality'] as String?,
      barangay: json['barangay'] as String?,
      photoUrl: json['photoUrl'] as String?,
      verificationStatus: json['verificationStatus'] as String? ?? 'unverified',
      adminNotes: json['adminNotes'] as String?,
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
      'verificationStatus': verificationStatus,
      if (adminNotes != null) 'adminNotes': adminNotes,
      'profileCompleted': profileCompleted,
    };
  }
}
