import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/verification/domain/entities/verification_data.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates the user's profile document. Safe to call even if a doc
  /// already exists for this uid — it merges rather than overwrites,
  /// so re-running it (e.g. from the magic-link flow) won't wipe out
  /// fields set elsewhere (like the profile-completion fields from
  /// CompleteProfileScreen).
  Future<void> createUserProfile({
    required String uid,
    required String fullname,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': fullname,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Kept for backward compatibility with any existing callers.
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
  /// Also updates the user's profile status to 'verification_pending'.
  // ❌ INCORRECT:
  // required VerificationRepositoryImpl data,

  // ✅ CORRECT:
  Future<void> submitVerificationRecord({
    required String userId,
    required VerificationData data,
    required String idCloudinaryUrl,
    required String selfieCloudinaryUrl,
  }) async {
    final batch = _firestore.batch();

    // 1. Create or overwrite doc in 'verifications' collection for Admin Panel
    final verificationRef = _firestore.collection('verifications').doc(userId);
    batch.set(verificationRef, {
      'userId': userId,
      'idType': data.idType,
      'extractedName': data.extractedName,
      'idNumber': data.idNumber,
      'idPhotoUrl': idCloudinaryUrl,
      'selfieUrl': selfieCloudinaryUrl,
      'hasDetectedFace': data.hasDetectedFace,
      'status': 'pending', // 'pending', 'approved', or 'rejected'
      'submittedAt': FieldValue.serverTimestamp(),
    });

    // 2. Optionally update the user's main profile status
    final userRef = _firestore.collection('users').doc(userId);
    batch.set(userRef, {
      'verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
