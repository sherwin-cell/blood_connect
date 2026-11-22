import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Returns 'submitted' when the user has already uploaded both ID images.
  /// Legacy records with status 'approved' are treated as submitted.
  /// No separate ID approval is required.
  Future<String?> getIdVerificationStatus(String userId) async {
    final snapshot = await _firestore
        .collection('id_verifications')
        .doc(userId)
        .get();

    if (!snapshot.exists) return null;
    final submission = snapshot.data();
    if (submission == null) return null;

    final front = submission['frontIdImageUrl'];
    final back = submission['backIdImageUrl'];
    if (front is! String ||
        front.trim().isEmpty ||
        back is! String ||
        back.trim().isEmpty) {
      return null;
    }

    return 'submitted';
  }

  /// Saves the first ID submission only. An existing document is never
  /// overwritten, including a legacy document marked 'approved'.
  /// This is a client-side transaction; Firestore rules must also prohibit
  /// non-admin updates/deletes to id_verifications.
  Future<String> saveIdVerificationSubmission({
    required String userId,
    required String frontUrl,
    String? backUrl,
    required RequestIdVerificationData data,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID is required.');
    }
    if (data.idType == null || data.idType!.trim().isEmpty) {
      throw ArgumentError('ID type is required.');
    }
    if (frontUrl.trim().isEmpty || backUrl == null || backUrl.trim().isEmpty) {
      throw ArgumentError('Both front and back ID image URLs are required.');
    }

    final submissionRef = _firestore.collection('id_verifications').doc(userId);

    return _firestore.runTransaction<String>((transaction) async {
      final existing = await transaction.get(submissionRef);
      if (existing.exists) {
        // Keep all previously submitted images and metadata unchanged.
        return submissionRef.id;
      }

      transaction.set(submissionRef, {
        'submissionId': submissionRef.id,
        'userId': userId,
        'status': 'submitted',
        'idType': data.idType,
        'frontIdImageUrl': frontUrl,
        'backIdImageUrl': backUrl,
        // This is only the app's local image-file check, not proof of ID authenticity.
        'validationStatus': data.validationStatus,
        'submittedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return submissionRef.id;
    });
  }

  /// Loads the saved ID document for reuse in future applications/requests.
  /// Permission errors propagate rather than being treated as a missing ID.
  Future<Map<String, dynamic>?> getLatestSavedIdSubmissionForUser(
    String userId,
  ) async {
    final snapshot = await _firestore
        .collection('id_verifications')
        .doc(userId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;

    return {...snapshot.data()!, 'submissionId': snapshot.id};
  }

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
      if (collection == 'donors') {
        return _submitDonorApplication(docId: docId, data: data);
      }

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

  /// Submits a donor application.
  ///
  /// donors/{uid} always holds the Current Application and every
  /// submission gets a new, unique applicationId. A user may submit again
  /// only if PRC rejected the current application and set
  /// reapplicationAllowed = true. The previous application is copied to
  /// donors/{uid}/application_history/{applicationId} and is never deleted.
  Future<String> _submitDonorApplication({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final donorRef = _firestore.collection('donors').doc(docId);
    final historyRef = donorRef.collection('application_history');
    final newApplicationId = _firestore.collection('donors').doc().id;

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(donorRef);

      final newData = <String, dynamic>{
        ...data,
        'applicationId': newApplicationId,
        'applicationStatus': 'pending',
        'donorStatus': 'pending',
        'status': 'pending',
      };

      final old = existing.data();

      if (existing.exists && old != null) {
        final oldStatus =
            (old['applicationStatus'] ?? old['donorStatus'] ?? old['status'])
                .toString()
                .trim()
                .toLowerCase();

        if (oldStatus != 'rejected' || old['reapplicationAllowed'] != true) {
          throw Exception(
            'You already have a donor application. You can apply again '
            'only if PRC rejected it and allowed reapplication.',
          );
        }

        final oldIdRaw = (old['applicationId'] ?? '').toString().trim();
        final oldApplicationId = oldIdRaw.isNotEmpty
            ? oldIdRaw
            : historyRef.doc().id;

        transaction.set(historyRef.doc(oldApplicationId), {
          ...old,
          'applicationId': oldApplicationId,
          'archivedAt': FieldValue.serverTimestamp(),
        });

        newData['createdAt'] = old['createdAt'] ?? FieldValue.serverTimestamp();
      } else {
        newData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Replace (not merge) so no review fields carry over.
      transaction.set(donorRef, newData);
    });

    return docId;
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
