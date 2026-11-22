import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/statuses.dart';

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
  /// The screen filters status == "active" (legacy "approved" accepted).
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

  /// Creates an offer from an approved donor for an active
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

    // --------------------------------------------------------------
    // VERIFY DONOR ELIGIBILITY (set by PRC after each donation)
    // --------------------------------------------------------------

    final donorSnapshot = await _firestore
        .collection('donors')
        .doc(donorId)
        .get();
    final donorData = donorSnapshot.data();

    if (donorData == null) {
      throw Exception('Your donor record could not be found.');
    }

    final blockingReason = DonorEligibility.blockingReason(donorData);
    if (blockingReason != null) {
      throw Exception(blockingReason);
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

    if (!RequestStatus.isOpenToDonors(requestStatus)) {
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
        .where('status', whereIn: OfferStatus.active)
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

    // Request details are copied onto the offer so the donor's
    // "My offers" list can show them without reading every request.
    await offersRef.add({
      'requestId': requestId,
      'requesterId': requestData['requesterId'] ?? requestData['userId'],
      'donorId': donorId,
      'donorName': donorName.trim(),
      'donorContact': donorContact.trim(),
      'donorBloodType': normalizedDonorBloodType,
      'requestBloodType': requestBloodType,
      'component': requestData['component'],
      'urgency': requestData['urgency'],
      'neededByDate': requestData['neededByDate'],
      'hospitalName': requestData['hospitalName'],
      'status': OfferStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ================================================================
  // WITHDRAW OFFER
  // ================================================================

  /// Lets a donor withdraw an offer that PRC has not completed yet.
  /// The offer is kept (not deleted) so PRC can see the history.
  Future<void> withdrawOffer({
    required String requestId,
    required String offerId,
  }) async {
    final offerRef = _firestore
        .collection('blood_requests')
        .doc(requestId)
        .collection('offers')
        .doc(offerId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(offerRef);
      final status = snapshot.data()?['status']?.toString();

      if (!snapshot.exists) {
        throw Exception('This offer no longer exists.');
      }
      if (!OfferStatus.isActive(status)) {
        throw Exception('This offer can no longer be withdrawn.');
      }

      tx.update(offerRef, {
        'status': OfferStatus.withdrawn,
        'withdrawnAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // DONOR -> MY OFFERS
  // ================================================================

  /// All offers made by [donorId], newest first.
  ///
  /// Uses a collection-group query on `offers`; sorted on the client so
  /// only the single-field `donorId` collection-group index is needed.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamMyOffers(
    String donorId,
  ) {
    return _firestore
        .collectionGroup('offers')
        .where('donorId', isEqualTo: donorId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final at = a.data()['createdAt'];
            final bt = b.data()['createdAt'];
            if (at is! Timestamp) return -1;
            if (bt is! Timestamp) return 1;
            return bt.compareTo(at);
          });
          return docs;
        });
  }
}
