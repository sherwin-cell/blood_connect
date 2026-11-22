/// Status values stored in Firestore.
///
/// These strings are persisted data: keep them in sync with `firestore.rules`,
/// Cloud Functions, and the admin app. Never rename an existing value without
/// migrating the documents that already use it.
library;

/// `blood_requests/{id}.status`
///
/// Lifecycle: pending → approved/active → matched → fulfilled,
/// with cancelled / rejected / expired as terminal states.
abstract final class RequestStatus {
  /// Submitted, waiting for PRC/admin review.
  static const pending = 'pending';

  /// Approved by PRC/admin and visible to donors.
  static const approved = 'approved';

  /// Legacy alias of [approved]; still written by older data.
  static const active = 'active';

  /// Enough donor offers have been accepted.
  static const matched = 'matched';

  /// Blood was received; request is closed.
  static const fulfilled = 'fulfilled';

  /// Withdrawn by the requester.
  static const cancelled = 'cancelled';

  /// Declined by PRC/admin.
  static const rejected = 'rejected';

  /// Closed automatically after its needed-by date passed.
  static const expired = 'expired';

  /// Requests donors can see and offer to.
  static const openToDonors = [approved, active];

  /// Requests that are still in progress; a user may only have one.
  static const inProgress = [pending, approved, active, matched];

  static bool isOpenToDonors(String? status) =>
      openToDonors.contains(status?.trim().toLowerCase());

  static bool isInProgress(String? status) =>
      inProgress.contains(status?.trim().toLowerCase());

  /// The requester may cancel any request that is still in progress.
  /// Must match the cancel rule in `firestore.rules`.
  static bool canBeCancelled(String? status) => isInProgress(status);

  /// Short label for status chips.
  static String label(String? status) {
    switch (status?.trim().toLowerCase()) {
      case pending:
        return 'Pending review';
      case approved:
      case active:
        return 'Open to donors';
      case matched:
        return 'Donor matched';
      case fulfilled:
        return 'Fulfilled';
      case cancelled:
        return 'Cancelled';
      case rejected:
        return 'Rejected';
      case expired:
        return 'Expired';
      default:
        return status ?? 'Unknown';
    }
  }
}

/// `blood_requests/{id}.urgency`
abstract final class RequestUrgency {
  static const urgent = 'Urgent';
  static const normal = 'Normal';
}

/// `blood_requests/{id}/offers/{offerId}.status`
///
/// Lifecycle: pending → approved (PRC confirmed the match) → donated,
/// with rejected (PRC declined) / withdrawn (donor) as terminal states.
///
/// PRC sets approved, rejected and donated from the admin app; the donor
/// may only withdraw.
abstract final class OfferStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const withdrawn = 'withdrawn';
  static const donated = 'donated';

  /// Legacy value written by an older requester-side "Accept" button.
  static const legacyAccepted = 'accepted';

  /// Offers that still block the donor from offering again, and that the
  /// donor may still withdraw.
  static const active = [pending, approved, legacyAccepted];

  static bool isActive(String? status) =>
      active.contains(status?.trim().toLowerCase());

  static bool isConfirmed(String? status) {
    final s = status?.trim().toLowerCase();
    return s == approved || s == legacyAccepted || s == donated;
  }

  /// Short label for status chips.
  static String label(String? status) {
    switch (status?.trim().toLowerCase()) {
      case pending:
        return 'Waiting for PRC';
      case approved:
      case legacyAccepted:
        return 'Confirmed by PRC';
      case rejected:
        return 'Not selected';
      case withdrawn:
        return 'Withdrawn';
      case donated:
        return 'Donated';
      default:
        return status ?? 'Unknown';
    }
  }
}

/// `donors/{uid}` donation eligibility, maintained by PRC in the admin app.
abstract final class DonorEligibility {
  /// Whether the donor may offer to donate today.
  ///
  /// PRC sets `isAvailableForDonation` and `nextEligibleDonationDate`
  /// (a `YYYY-MM-DD` string) after each donation.
  static bool canDonate(Map<String, dynamic> donor, {DateTime? today}) =>
      blockingReason(donor, today: today) == null;

  /// A user-facing reason the donor cannot offer, or null if they can.
  static String? blockingReason(Map<String, dynamic> donor, {DateTime? today}) {
    final status = donor['donorStatus']?.toString().trim().toLowerCase();
    if (status != DonorStatus.approved || donor['isDonor'] != true) {
      return 'Your donor application must be approved by PRC first.';
    }
    if (donor['isAvailableForDonation'] != true) {
      return 'You are currently marked unavailable for donation.';
    }
    final next = nextEligibleDate(donor);
    final now = today ?? DateTime.now();
    if (next != null && _dateOnly(now).isBefore(next)) {
      return 'You can donate again from ${_format(next)}.';
    }
    return null;
  }

  /// Parses `nextEligibleDonationDate` (`YYYY-MM-DD`), or null.
  static DateTime? nextEligibleDate(Map<String, dynamic> donor) {
    final raw = donor['nextEligibleDonationDate'];
    if (raw is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// `donors/{uid}.donorStatus` (also mirrored to `status` / `applicationStatus`).
abstract final class DonorStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

/// `id_verifications/{id}.status`
abstract final class IdVerificationStatus {
  /// Uploaded, waiting for admin review.
  static const submitted = 'submitted';
  static const approved = 'approved';
  static const rejected = 'rejected';

  /// Legacy values still found in older documents.
  static const legacyPending = 'pending';
  static const legacyVerified = 'verified';
}

/// Result of the on-device face match.
abstract final class FaceVerificationResult {
  static const verified = 'verified';
  static const failed = 'failed';
}
