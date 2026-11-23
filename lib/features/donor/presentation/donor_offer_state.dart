import 'package:flutter/material.dart';

import '../../../core/constants/statuses.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/streams.dart';
import '../../blood_request/domain/request_summary.dart';
import '../data/repositories/donor_repository_impl.dart';

/// What the signed-in user may do on donor-facing request screens.
class DonorOfferState {
  const DonorOfferState({
    required this.donor,
    this.activeOfferRequestIds = const {},
    this.ownRequestIds = const {},
  });

  /// `donors/{uid}`, or null when the user never applied.
  final Map<String, dynamic>? donor;

  /// Requests the donor has a pending or confirmed offer on.
  final Set<String> activeOfferRequestIds;

  /// The user's own requests (never offered to them).
  final Set<String> ownRequestIds;

  String get bloodType =>
      (donor?['bloodType'] ?? '').toString().trim().toUpperCase();

  /// Why this donor cannot offer at all right now, or null.
  String? get blockingReason {
    final d = donor;
    if (d == null) {
      return 'Apply as a blood donor and wait for PRC approval before '
          'offering to donate.';
    }
    final reason = DonorEligibility.blockingReason(d);
    if (reason != null) return reason;
    if (bloodType.isEmpty) {
      return 'Your donor record has no blood type yet. Please contact PRC.';
    }
    return null;
  }

  bool hasOffered(String requestId) =>
      activeOfferRequestIds.contains(requestId);

  /// Why this donor cannot offer on [request], or null when they can.
  String? reasonFor(RequestSummary request) {
    if (ownRequestIds.contains(request.id)) {
      return 'This is your own blood request.';
    }
    if (hasOffered(request.id)) {
      return 'You already offered to help. PRC will review your offer.';
    }
    if (!request.isOpen) {
      return 'This request is no longer accepting donor offers.';
    }
    final blocked = blockingReason;
    if (blocked != null) return blocked;
    if (request.bloodType != bloodType) {
      return 'Only ${request.bloodType} donors can offer for this request.';
    }
    return null;
  }

  /// Live state for [uid]: donor record, active offers and own requests.
  static Stream<DonorOfferState> watch(
    String uid, {
    DonorRepositoryImpl? repository,
  }) {
    final repo = repository ?? DonorRepositoryImpl();
    return combineLatest2(
      () => combineLatest2(
        () => repo.watchDonor(uid),
        () => repo.streamMyOffers(uid),
        (donor, offers) => (donor, offers),
      ),
      () => repo.ownRequestIds(uid),
      (pair, own) => DonorOfferState(
        donor: pair.$1,
        activeOfferRequestIds: {
          for (final offer in pair.$2)
            if (OfferStatus.isActive(offer.data()['status']?.toString()))
              (offer.data()['requestId'] ?? offer.reference.parent.parent!.id)
                  .toString(),
        },
        ownRequestIds: own,
      ),
    );
  }
}

/// Medical eligibility notice shown before every offer. True to continue.
Future<bool> confirmMedicalNotice(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Medical Eligibility Notice',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: const Text(
        'Offering to donate does not guarantee medical eligibility. You will '
        'undergo a standard medical screening at the designated blood '
        'donation center before donating. PRC reviews every offer and '
        'contacts confirmed donors.',
        style: TextStyle(fontSize: 14, color: Colors.black87),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryRed,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('I Understand & Offer'),
        ),
      ],
    ),
  );
  return ok == true;
}
