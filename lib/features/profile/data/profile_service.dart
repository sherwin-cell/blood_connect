import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseFirestore _firestore;

  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns a real-time stream of the user profile document for reactive navigation (AuthGate / ProfileGate).
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfileStream(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Checks once if the user has completed their profile.
  Future<bool> isProfileCompleted(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['profileCompleted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Updates existing users/{uid} document with completed profile fields.
  /// Sets [profileCompleted] to `true` to instantly trigger reactive gate transitions.
  Future<void> updateProfile({
    required String uid,
    required String fullName,
    required String phoneNumber,
    required String bloodType,
    String? gender,
    DateTime? birthDate,
    String? province,
    String? municipality,
    String? barangay,
    String? photoUrl,
    bool profileCompleted = true,
  }) async {
    final Map<String, dynamic> updateData = {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'bloodType': bloodType,
      'gender': gender,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate) : null,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      'photoUrl': photoUrl,
      'profileCompleted': profileCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Remove null optional entries to keep Firestore documents clean
    updateData.removeWhere((key, value) => value == null);

    await _firestore
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));
  }
}
