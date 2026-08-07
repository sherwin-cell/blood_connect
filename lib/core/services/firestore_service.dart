import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/profile/domain/user_profile_model.dart';
import '../../features/verification/domain/entities/verification_data.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of user profile updates for reactive UI listening (ProfileGate, HomeDashboard)
  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      final data = doc.data()!;
      data['uid'] = data['uid'] ?? doc.id;
      return UserProfile.fromFirestore(data);
    });
  }

  /// Fetches user profile once (Future)
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    data['uid'] = data['uid'] ?? doc.id;
    return UserProfile.fromFirestore(data);
  }

  /// Creates initial user profile on registration or Google Sign-In
  Future<void> createUserProfile({
    required String uid,
    String? fullname,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      if (fullname != null) 'fullName': fullname,
      'email': email,
      'profileCompleted': false,
      'verificationStatus': 'unverified',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Called by CompleteProfileScreen when saving form details.
  /// Note: fullName, gender, and birthDate are made optional because
  /// official identity details are verified in the OCR Verification stage.
  Future<void> updateProfile({
    required String uid,
    String? fullName,
    required String phoneNumber,
    required String bloodType,
    String? gender,
    DateTime? birthDate,
    String? province,
    String? municipality,
    String? barangay,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      if (fullName != null) 'fullName': fullName,
      'phoneNumber': phoneNumber,
      'bloodType': bloodType,
      if (gender != null) 'gender': gender,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      if (province != null) 'province': province,
      if (municipality != null) 'municipality': municipality,
      if (barangay != null) 'barangay': barangay,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Kept for backward compatibility
  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
  }) async {
    await createUserProfile(uid: uid, fullname: name, email: email);
  }

  Future<bool> userExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  // ==========================================
  // IDENTITY VERIFICATION METHODS
  // ==========================================

  /// Saves the user's identity verification submission for PRC Admin review.
  /// Automatically updates official identity details on the user record.
  Future<void> submitVerificationRecord({
    required String userId,
    required VerificationData data,
    required String idCloudinaryUrl,
    String? backIdCloudinaryUrl,
    required String selfieCloudinaryUrl,
  }) async {
    final batch = _firestore.batch();

    // 1. Create/Update verification record for admin audit
    final verificationRef = _firestore.collection('verifications').doc(userId);
    batch.set(verificationRef, {
      'userId': userId,
      'idType': data.idType,
      'idNumber': data.idNumber,
      'extractedName': data.extractedName,
      'extractedBirthDate': data.extractedBirthDate,
      'extractedGender': data.extractedGender,
      'idPhotoUrl': idCloudinaryUrl,
      'backIdPhotoUrl': backIdCloudinaryUrl,
      'selfieUrl': selfieCloudinaryUrl,
      'hasDetectedFace': data.hasDetectedFace,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Atomically sync extracted identity details & status to `users` profile
    final userRef = _firestore.collection('users').doc(userId);
    batch.set(userRef, {
      if (data.extractedName != null) 'fullName': data.extractedName,
      if (data.extractedBirthDate != null) 'birthDate': data.extractedBirthDate,
      if (data.extractedGender != null) 'gender': data.extractedGender,
      'verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
