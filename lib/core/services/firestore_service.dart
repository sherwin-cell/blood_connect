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

  /// Looks up an existing Blood-Connect profile by email (case-insensitive).
  Future<UserProfile?> findUserProfileByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      // Legacy profiles may have been stored with original casing
      final fallback = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (fallback.docs.isEmpty) return null;
      final data = fallback.docs.first.data();
      data['uid'] = data['uid'] ?? fallback.docs.first.id;
      return UserProfile.fromFirestore(data);
    }

    final data = snapshot.docs.first.data();
    data['uid'] = data['uid'] ?? snapshot.docs.first.id;
    return UserProfile.fromFirestore(data);
  }

  /// Creates initial user profile if missing.
  /// Does not overwrite [profileCompleted] or other fields on repeat sign-ins.
  Future<void> createUserProfile({
    required String uid,
    String? fullname,
    required String email,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'uid': uid,
        if (fullname != null && fullname.isNotEmpty) 'fullName': fullname,
        'email': email.trim().toLowerCase(),
        'profileCompleted': false,
        'verificationStatus': 'unverified',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Existing profile: only refresh identity basics — never reset completion.
    await docRef.set({
      'email': email.trim().toLowerCase(),
      if (fullname != null && fullname.isNotEmpty) 'fullName': fullname,
    }, SetOptions(merge: true));
  }

  /// Called by CompleteProfileScreen when saving operational contact & location details.
  Future<void> updateProfile({
    required String uid,
    required String phoneNumber,
    String? province,
    String? municipality,
    String? barangay,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'phoneNumber': phoneNumber,
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
  // (Optional feature path — not part of auth routing)
  // ==========================================

  /// Saves the user's identity verification submission along with ARSA Face API
  /// comparison scores for PRC Admin review.
  ///
  /// Caller must only invoke this after a successful ARSA comparison.
  /// Status remains `pending` for admin review — never auto-verified here.
  Future<void> submitVerificationRecord({
    required String userId,
    required VerificationData data,
    required String idCloudinaryUrl,
    String? backIdCloudinaryUrl,
    required String selfieCloudinaryUrl,
    double? faceMatchConfidence,
    bool? faceMatchPassed,
  }) async {
    final batch = _firestore.batch();

    final double? confidenceScore =
        faceMatchConfidence ?? data.faceMatchConfidence;
    final bool? matchPassed = faceMatchPassed ?? data.faceMatchPassed;

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
      'faceMatchConfidence': confidenceScore,
      'faceMatchPassed': matchPassed,
      'verificationProvider': data.verificationProvider ?? 'arsa',
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
