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
  final bool isVerified;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    this.gender,
    this.birthDate,
    required this.bloodType,
    this.province,
    this.municipality,
    this.barangay,
    this.photoUrl,
    this.isVerified = false,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      gender: json['gender'],
      birthDate: json['birthDate'] != null
          ? (json['birthDate'] as Timestamp).toDate()
          : null,
      bloodType: json['bloodType'] ?? '',
      province: json['province'],
      municipality: json['municipality'],
      barangay: json['barangay'],
      photoUrl: json['photoUrl'],
      isVerified: json['isVerified'] ?? false,
      profileCompleted: json['profileCompleted'] ?? false,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
