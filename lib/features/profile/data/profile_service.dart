import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/birthday.dart';

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

  /// The Date of Birth saved on `users/{uid}` (entered at Sign Up), or
  /// null for accounts that never entered one (Google / legacy).
  Future<DateTime?> fetchBirthday(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return Birthday.fromUserData(doc.data());
  }

  /// Saves [birthDate] to `users/{uid}.birthday` only if none is stored
  /// yet (legacy accounts), so a birthday is entered once and never
  /// overwritten from the application forms.
  Future<void> saveBirthdayIfMissing(String uid, DateTime birthDate) async {
    final ref = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (Birthday.fromUserData(snap.data()) != null) return;
      transaction.set(ref, {
        'birthday': Birthday.format(birthDate),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Updates existing users/{uid} document with completed profile fields.
  /// Sets [profileCompleted] to `true` to instantly trigger reactive gate transitions.
  Future<void> updateProfile({
    required String uid,
    String? fullName,
    required String phoneNumber,
    String? birthday,
    String? nationality,
    String? province,
    String? municipality,
    String? barangay,
    String? purok,
  }) async {
    final Map<String, dynamic> data = {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (fullName != null) data['fullName'] = fullName;
    if (birthday != null) data['birthday'] = birthday;
    if (nationality != null) data['nationality'] = nationality;
    if (province != null) data['province'] = province;
    if (municipality != null) data['municipality'] = municipality;
    if (barangay != null) data['barangay'] = barangay;
    if (purok != null) data['purok'] = purok;

    // Use set+merge so first-time Google users without a stub still succeed.
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}
