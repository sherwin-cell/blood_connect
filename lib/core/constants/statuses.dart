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
}

/// `blood_requests/{id}.urgency`
abstract final class RequestUrgency {
  static const urgent = 'Urgent';
  static const normal = 'Normal';
}

/// `blood_requests/{id}/offers/{donorId}.status`
///
/// Lifecycle: pending → accepted → donated,
/// with declined / withdrawn as terminal states.
abstract final class OfferStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const declined = 'declined';
  static const withdrawn = 'withdrawn';
  static const donated = 'donated';

  /// Offers that still block the donor from offering again.
  static const active = [pending, accepted];
}

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
