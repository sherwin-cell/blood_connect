import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/profile/domain/user_profile_model.dart';
import '../../features/verification/domain/entities/face_verification_data.dart';
import '../../features/verification/domain/entities/request_id_verification_data.dart';

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
        'faceVerified': false,
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
  // FACE VERIFICATION (ACCOUNT)
  // ==========================================

  /// Fetches whether the user's face has been verified.
  Future<bool> getFaceVerificationStatus(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    return data['faceVerified'] as bool? ?? false;
  }

  /// Stores automatic face-verification results on the user document only.
  Future<void> saveFaceVerification({
    required String userId,
    required String selfieCloudinaryUrl,
    required FaceVerificationData data,
  }) async {
    final now = FieldValue.serverTimestamp();
    final result =
        data.verificationResult ??
        (data.hasDetectedFace && (data.faceMatchPassed ?? true)
            ? 'verified'
            : 'failed');
    final verified = result == 'verified';

    await _firestore.collection('users').doc(userId).set({
      'selfieImageUrl': selfieCloudinaryUrl,
      'faceVerified': verified,
      'faceVerification': {
        'hasDetectedFace': data.hasDetectedFace,
        'faceMatchConfidence': data.faceMatchConfidence,
        'faceMatchPassed': data.faceMatchPassed,
        'verificationProvider': data.verificationProvider ?? 'local_liveness',
        'verificationResult': result,
        'selfieImageUrl': selfieCloudinaryUrl,
        'verifiedAt': now,
      },
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  // ==========================================
  // ID VERIFICATION STATUS & SUBMISSION
  // ==========================================

  /// Fetches the user's current ID verification status from their user document.
  Future<String?> getIdVerificationStatus(String userId) async {
    try {
      // 1. First, verify that an actual submission document exists in id_verifications
      final idSubmissionDoc = await _firestore
          .collection('id_verifications')
          .doc(userId)
          .get();

      if (!idSubmissionDoc.exists || idSubmissionDoc.data() == null) {
        // No submission record exists, so the account cannot be verified/approved.
        return null;
      }

      // 2. If the submission exists, check the status on the user profile (or the submission itself)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data();
      if (data == null) return null;

      return data['idVerificationStatus'] as String?;
    } catch (e) {
      debugPrint('Error checking ID verification status: $e');
      return null;
    }
  }

  /// Creates a new ID verification submission for admin review.
  /// Creates a new ID verification submission and instantly approves it (since there is no admin app).
  Future<String> saveIdVerificationSubmission({
    required String userId,
    required String frontUrl,
    String? backUrl,
    required RequestIdVerificationData data,
  }) async {
    final now = FieldValue.serverTimestamp();
    final submissionRef = _firestore.collection('id_verifications').doc(userId);

    // 1. Save submission data with 'approved' status
    await submissionRef.set({
      'submissionId': submissionRef.id,
      'userId': userId,
      'status': 'approved', // Changed from 'pending' to 'approved'
      'idType': data.idType,
      'frontIdImageUrl': frontUrl,
      'backIdImageUrl': backUrl,
      'validationStatus': data.validationStatus,
      'submittedAt': data.submittedAt?.toIso8601String(),
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    // 2. Update the user document so getIdVerificationStatus reads 'approved' immediately
    await _firestore.collection('users').doc(userId).set({
      'idVerificationStatus': 'approved',
      'isVerified': true,
      'updatedAt': now,
    }, SetOptions(merge: true));

    return submissionRef.id;
  }

  /// FIXED: Fetches the latest ID submission cleanly by direct document reference
  /// to avoid collection-level query permission errors when no document exists.
  Future<Map<String, dynamic>?> getLatestSavedIdSubmissionForUser(
    String userId,
  ) async {
    try {
      final docRef = _firestore.collection('id_verifications').doc(userId);
      final docSnap = await docRef.get();

      if (!docSnap.exists || docSnap.data() == null) {
        return null;
      }

      final data = docSnap.data()!;
      data['submissionId'] = docSnap.id;
      return data;
    } catch (e) {
      debugPrint(
        'Safe ID lookup caught exception (expected if unsubmitted): $e',
      );
      return null;
    }
  }

  // ==========================================
  // REQUEST + ID VERIFICATION
  // ==========================================

  /// Creates or updates a request document and attaches ID verification to it.
  Future<String> submitRequestWithId({
    required String collection,
    String? documentId,
    required Map<String, dynamic> requestPayload,
    required RequestIdVerificationData idData,
    required String frontIdImageUrl,
    String? backIdImageUrl,
    String? idVerificationSubmissionId,
  }) async {
    final now = FieldValue.serverTimestamp();

    final docId =
        documentId ??
        (collection == 'donors' ? requestPayload['userId'] : null);

    final idVerification = {
      ...idData.toFirestoreMap(
        frontIdImageUrl: frontIdImageUrl,
        backIdImageUrl: backIdImageUrl,
      ),
      'submittedAt': now,
    };

    final data = {
      ...requestPayload,
      if (idVerificationSubmissionId != null &&
          idVerificationSubmissionId.isNotEmpty)
        'idVerificationSubmissionId': idVerificationSubmissionId,
      'idVerification': idVerification,
      'status': requestPayload['status'] ?? 'pending',
      'updatedAt': now,
    };

    if (docId != null) {
      await _firestore
          .collection(collection)
          .doc(docId)
          .set(data, SetOptions(merge: true));
      return docId;
    }

    data['createdAt'] = now;
    final ref = await _firestore.collection(collection).add(data);
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserBloodRequests(
    String userId,
  ) {
    return _firestore
        .collection('blood_requests')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserDonorApplication(
    String userId,
  ) {
    return _firestore.collection('donors').doc(userId).snapshots();
  }

  /// Adds a donor's offer to help a specific blood request subcollection
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {
    await _firestore
        .collection('blood_requests')
        .doc(requestId)
        .collection('offers')
        .add({
          'donorId': donorId,
          'donorName': donorName,
          'donorContact': donorContact,
          'donorBloodType': donorBloodType,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
