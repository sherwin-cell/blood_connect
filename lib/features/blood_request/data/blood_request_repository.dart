import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';

/// Requester-side actions on `blood_requests`.
///
/// PRC controls approval, donor matching and fulfilment from the admin app.
/// The requester may only cancel their own in-progress request.
class BloodRequestRepository {
  BloodRequestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Cancels [requestId] on behalf of its owner [userId].
  ///
  /// Also closes the donor-facing `request_summaries` entry when PRC has
  /// already published one, so donors stop seeing the request.
  Future<void> cancelRequest({
    required String requestId,
    required String userId,
    String? reason,
  }) async {
    final requestRef = _firestore.collection('blood_requests').doc(requestId);
    final summaryRef = _firestore
        .collection('request_summaries')
        .doc(requestId);

    await _firestore.runTransaction((tx) async {
      final request = await tx.get(requestRef);
      final summary = await tx.get(summaryRef);
      final data = request.data();

      if (data == null) {
        throw Exception('This blood request no longer exists.');
      }

      final ownerId = data['requesterId'] ?? data['userId'];
      if (ownerId != userId) {
        throw Exception('You can only cancel your own blood request.');
      }

      final status = data['status']?.toString();
      if (!RequestStatus.canBeCancelled(status)) {
        throw Exception(
          'This request is already ${RequestStatus.label(status).toLowerCase()}.',
        );
      }

      final trimmedReason = reason?.trim();
      tx.update(requestRef, {
        'status': RequestStatus.cancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': userId,
        if (trimmedReason != null && trimmedReason.isNotEmpty)
          'cancellationReason': trimmedReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (summary.exists) {
        tx.update(summaryRef, {
          'status': RequestStatus.cancelled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// Offers on [requestId], newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamOffers(String requestId) {
    return _firestore
        .collection('blood_requests')
        .doc(requestId)
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
