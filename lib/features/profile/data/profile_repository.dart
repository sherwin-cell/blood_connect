import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../verification/data/services/cloudinary_service.dart';
import '../domain/notification_preferences.dart';
import '../domain/user_profile_model.dart';

/// Personal details the user may change from Edit Profile.
class PersonalInfoUpdate {
  const PersonalInfoUpdate({
    required this.fullName,
    required this.phoneNumber,
    this.birthDate,
    this.gender,
    this.nationality,
    this.purok,
    this.barangay,
    this.municipality,
    this.province,
  });

  final String fullName;
  final String phoneNumber;
  final DateTime? birthDate;
  final String? gender;
  final String? nationality;
  final String? purok;
  final String? barangay;
  final String? municipality;
  final String? province;

  /// The only `users/{uid}` keys Edit Profile writes. None of them is in
  /// the protected list of the owner update rule in firestore.rules.
  static const editableFields = {
    'fullName',
    'phoneNumber',
    'birthday',
    'gender',
    'nationality',
    'purok',
    'barangay',
    'municipality',
    'province',
  };

  /// Firestore fields; blank optional values are removed, not stored empty.
  Map<String, Object> toFirestore() {
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    final b = birthDate;
    final data = <String, Object>{
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
    };
    void put(String key, String? value) =>
        data[key] = clean(value) ?? FieldValue.delete();
    put(
      'birthday',
      b == null
          ? null
          : '${b.year.toString().padLeft(4, '0')}-'
                '${b.month.toString().padLeft(2, '0')}-'
                '${b.day.toString().padLeft(2, '0')}',
    );
    put('gender', gender);
    put('nationality', nationality);
    put('purok', purok);
    put('barangay', barangay);
    put('municipality', municipality);
    put('province', province);
    return data;
  }
}

abstract class ProfileRepository {
  Stream<UserProfile?> watch(String uid);
  Future<void> updatePersonalInfo(String uid, PersonalInfoUpdate update);

  /// Uploads the picture and stores its URL as `photoUrl`; returns the URL.
  Future<String> updateProfilePhoto(String uid, File photo);
  Future<void> updateNotificationPreferences(
    String uid,
    NotificationPreferences preferences,
  );
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({this.firestore, CloudinaryService? cloudinary})
    : _cloudinary = cloudinary ?? CloudinaryService();

  /// Defaults to [FirebaseFirestore.instance], resolved on first use.
  final FirebaseFirestore? firestore;
  final CloudinaryService _cloudinary;

  // Resolved lazily so screens can be built in tests without Firebase.
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      (firestore ?? FirebaseFirestore.instance).collection('users').doc(uid);

  @override
  Stream<UserProfile?> watch(String uid) => _user(uid).snapshots().map(
    (doc) => doc.exists && doc.data() != null
        ? UserProfile.fromFirestore({...doc.data()!, 'uid': doc.id})
        : null,
  );

  @override
  Future<void> updatePersonalInfo(String uid, PersonalInfoUpdate update) =>
      _user(uid).update({
        ...update.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<String> updateProfilePhoto(String uid, File photo) async {
    final url = await _cloudinary.uploadImage(photo);
    await _user(
      uid,
    ).update({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()});
    return url;
  }

  @override
  Future<void> updateNotificationPreferences(
    String uid,
    NotificationPreferences preferences,
  ) => _user(uid).update({
    NotificationPreferences.field: preferences.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
