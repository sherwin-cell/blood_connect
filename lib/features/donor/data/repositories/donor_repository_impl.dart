import 'package:cloud_firestore/cloud_firestore.dart';

class DonorRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================================================================
  // DONOR -> APPROVED BLOOD REQUESTS
  // ================================================================

  /// Returns blood requests with the EXACT SAME blood type
  /// as the donor.
  ///
  /// Matching rule:
  ///     donor blood type == request blood type
  ///
  /// Example:
  ///     A+ donor  -> A+ requests only
  ///     O+ donor  -> O+ requests only
  ///     AB- donor -> AB- requests only
  ///
  /// The Firestore query filters only by bloodType.
  /// The screen filters status == "approved".
  ///
  /// We intentionally keep status filtering outside the query
  /// to avoid requiring a composite Firestore index.
  Stream<QuerySnapshot<Map<String, dynamic>>> getCompatibleRequestsStream(
    String donorBloodType,
  ) {
    final normalizedBloodType = donorBloodType.trim().toUpperCase();

    if (normalizedBloodType.isEmpty) {
      return _firestore
          .collection('blood_requests')
          .where('bloodType', isEqualTo: '__NO_MATCH__')
          .snapshots();
    }

    return _firestore
        .collection('blood_requests')
        .where('bloodType', isEqualTo: normalizedBloodType)
        .snapshots();
  }

  // ================================================================
  // REQUESTER -> APPROVED / AVAILABLE DONORS
  // ================================================================

  /// Returns donors with the EXACT SAME blood type
  /// as the request.
  ///
  /// Matching rule:
  ///     request blood type == donor blood type
  ///
  /// Example:
  ///     A+ request  -> A+ donors only
  ///     O+ request  -> O+ donors only
  ///     AB- request -> AB- donors only
  ///
  /// The Firestore query filters only by bloodType.
  ///
  /// The screen must additionally require:
  ///     donorStatus == "approved"
  ///     isAvailableForDonation == true
  ///
  /// The current user is also excluded by the screen.
  Stream<QuerySnapshot<Map<String, dynamic>>> getCompatibleDonorsStream(
    String requestBloodType,
  ) {
    final normalizedBloodType = requestBloodType.trim().toUpperCase();

    if (normalizedBloodType.isEmpty) {
      return _firestore
          .collection('donors')
          .where('bloodType', isEqualTo: '__NO_MATCH__')
          .snapshots();
    }

    return _firestore
        .collection('donors')
        .where('bloodType', isEqualTo: normalizedBloodType)
        .snapshots();
  }

  // ================================================================
  // OFFER TO DONATE
  // ================================================================

  /// Creates an offer from an approved donor for an approved
  /// blood request.
  ///
  /// The caller is responsible for making sure:
  /// - the donor is approved
  /// - the donor is available
  /// - the request is approved
  /// - donor/request blood types are exactly equal
  ///
  /// This method prevents the same donor from having more than
  /// one active offer for the same request.
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {
    final normalizedDonorBloodType = donorBloodType.trim().toUpperCase();

    if (requestId.trim().isEmpty) {
      throw Exception('Missing blood request ID.');
    }

    if (donorId.trim().isEmpty) {
      throw Exception('Missing donor ID.');
    }

    if (normalizedDonorBloodType.isEmpty) {
      throw Exception('Missing donor blood type.');
    }

    final requestRef = _firestore.collection('blood_requests').doc(requestId);

    // --------------------------------------------------------------
    // VERIFY REQUEST
    // --------------------------------------------------------------

    final requestSnapshot = await requestRef.get();

    if (!requestSnapshot.exists) {
      throw Exception('Blood request no longer exists.');
    }

    final requestData = requestSnapshot.data();

    if (requestData == null) {
      throw Exception('Unable to read blood request.');
    }

    final requestStatus = (requestData['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (requestStatus != 'approved') {
      throw Exception(
        'This blood request is no longer available for donation offers.',
      );
    }

    // --------------------------------------------------------------
    // VERIFY EXACT BLOOD TYPE MATCH
    // --------------------------------------------------------------

    final requestBloodType = (requestData['bloodType'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    if (requestBloodType.isEmpty ||
        requestBloodType != normalizedDonorBloodType) {
      throw Exception(
        'Your blood type does not exactly match this blood request.',
      );
    }

    // --------------------------------------------------------------
    // CHECK EXISTING ACTIVE OFFER
    // --------------------------------------------------------------

    final offersRef = requestRef.collection('offers');

    final existingOffer = await offersRef
        .where('donorId', isEqualTo: donorId)
        .where('status', whereIn: ['pending', 'accepted'])
        .limit(1)
        .get();

    if (existingOffer.docs.isNotEmpty) {
      throw Exception(
        'You have already submitted an active offer for this request.',
      );
    }

    // --------------------------------------------------------------
    // CREATE OFFER
    // --------------------------------------------------------------

    await offersRef.add({
      'donorId': donorId,
      'donorName': donorName.trim(),
      'donorContact': donorContact.trim(),
      'donorBloodType': normalizedDonorBloodType,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
