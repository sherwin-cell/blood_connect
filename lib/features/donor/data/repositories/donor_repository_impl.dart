import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/statuses.dart';
import '../../../blood_request/domain/request_summary.dart';

/// Donor-side reads and writes.
///
/// Donors only see `request_summaries` (anonymised by PRC); full
/// `blood_requests` are readable only by their owner and PRC.
class DonorRepositoryImpl {
  DonorRepositoryImpl({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;

  // Resolved lazily so screens can be built in tests without Firebase.
  FirebaseFirestore get _firestore => _db ?? FirebaseFirestore.instance;

  // ================================================================
  // DONOR -> OPEN REQUESTS (anonymised summaries)
  // ================================================================

  /// Every request open to donors, newest first. Donors offer only on
  /// their own blood type (enforced by firestore.rules); the rest are shown
  /// read-only. Sorted here so no extra composite index is needed.
  Stream<List<RequestSummary>> openSummaries() => _firestore
      .collection('request_summaries')
      .where('status', whereIn: RequestStatus.openToDonors)
      .snapshots()
      .map((s) {
        final list = [
          for (final d in s.docs) RequestSummary.fromFirestore(d.id, d.data()),
        ];
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        list.sort(
          (a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch),
        );
        return list;
      });

  /// One summary, live (null once PRC removes it).
  Stream<RequestSummary?> watchSummary(String requestId) => _firestore
      .collection('request_summaries')
      .doc(requestId)
      .snapshots()
      .map(
        (d) => d.data() == null
            ? null
            : RequestSummary.fromFirestore(d.id, d.data()!),
      );

  /// Ids of the user's own requests, so they are not offered to them.
  Stream<Set<String>> ownRequestIds(String uid) => _firestore
      .collection('blood_requests')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id});

  /// The donor's own `donors/{uid}` record, live.
  Stream<Map<String, dynamic>?> watchDonor(String uid) =>
      _firestore.collection('donors').doc(uid).snapshots().map((d) => d.data());

  // ================================================================
  // OFFER TO DONATE
  // ================================================================

  /// Creates an offer from the signed-in approved donor for an open
  /// request. The only way the app creates offers.
  ///
  /// Name, contact and blood type come from the donor's own application,
  /// and request details from the anonymised summary. firestore.rules
  /// re-check eligibility, the request status, the blood type and that the
  /// donor is not the requester.
  Future<void> offerToDonate({
    required String requestId,
    required String donorId,
  }) async {
    if (requestId.trim().isEmpty) {
      throw Exception('Missing blood request ID.');
    }
    if (donorId.trim().isEmpty) {
      throw Exception('Missing donor ID.');
    }

    final donorData = (await _firestore.collection('donors').doc(donorId).get())
        .data();
    if (donorData == null) {
      throw Exception('Your donor record could not be found.');
    }
    final blockingReason = DonorEligibility.blockingReason(donorData);
    if (blockingReason != null) {
      throw Exception(blockingReason);
    }
    final donorBloodType = (donorData['bloodType'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    final summaryData =
        (await _firestore.collection('request_summaries').doc(requestId).get())
            .data();
    if (summaryData == null) {
      throw Exception('This blood request is no longer available.');
    }
    final summary = RequestSummary.fromFirestore(requestId, summaryData);
    if (!summary.isOpen) {
      throw Exception(
        'This blood request is no longer available for donation offers.',
      );
    }
    if (summary.bloodType.isEmpty || summary.bloodType != donorBloodType) {
      throw Exception(
        'Your blood type does not exactly match this blood request.',
      );
    }

    final offersRef = _firestore
        .collection('blood_requests')
        .doc(requestId)
        .collection('offers');

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

    // No donor name or contact here: the requester can read their request's
    // offers, and donors stay anonymous to requesters. PRC reads the
    // donor's details from donors/{donorId} (firestore.rules refuses
    // offers that carry them).
    await offersRef.add({
      'requestId': requestId,
      'donorId': donorId,
      'donorBloodType': donorBloodType,
      ...summary.offerFields(),
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
