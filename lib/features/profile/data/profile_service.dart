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
    String? fullName, // Made optional since identity verification extracts this
    required String phoneNumber,
    required String bloodType,
    String? province,
    String? municipality,
    String? barangay,
  }) async {
    final Map<String, dynamic> data = {
      'phoneNumber': phoneNumber,
      'bloodType': bloodType,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (fullName != null) data['fullName'] = fullName;
    if (province != null) data['province'] = province;
    if (municipality != null) data['municipality'] = municipality;
    if (barangay != null) data['barangay'] = barangay;

    await _firestore.collection('users').doc(uid).update(data);
  }
}
