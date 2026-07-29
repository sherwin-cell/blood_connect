import 'package:cloud_firestore/cloud_firestore.dart';

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
}
