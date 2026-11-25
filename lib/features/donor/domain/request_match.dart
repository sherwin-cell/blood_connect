import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';
import '../../blood_request/domain/request_progress.dart';

/// Where donor matching stands for one approved blood request.
enum MatchState {
  /// PRC confirmed at least one donor (or marked the request matched).
  matched,

  /// Donors offered and are waiting for PRC review.
  inProgress,

  /// No donor has offered yet.
  noMatch,
}

DateTime? _date(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

/// A donor PRC confirmed for a request, as the requester may see them:
/// an anonymised code and blood type only. Never the donor's name,
/// contact, photo or account ID.
class MatchedDonor {
  const MatchedDonor({
    required this.offerId,
    required this.code,
    required this.bloodType,
    required this.donated,
    this.confirmedAt,
    this.donatedAt,
  });

  factory MatchedDonor.fromOffer(String offerId, Map<String, dynamic> data) {
    final blood = (data['donorBloodType'] ?? data['requestBloodType'] ?? '—')
        .toString()
        .trim()
        .toUpperCase();
    return MatchedDonor(
      offerId: offerId,
      code: donorCode(data['donorCode']),
      bloodType: blood.isEmpty ? '—' : blood,
      donated:
          data['status']?.toString().trim().toLowerCase() ==
          OfferStatus.donated,
      confirmedAt: _date(data['approvedAt']),
      donatedAt: _date(data['donatedAt']),
    );
  }

  final String offerId;

  /// The PRC-assigned code, e.g. "DNR-0023", or null while PRC has not
  /// assigned one yet.
  final String? code;
  final String bloodType;
  final bool donated;
  final DateTime? confirmedAt;
  final DateTime? donatedAt;

  /// Shown in place of a code PRC has not assigned yet.
  static const pendingCodeLabel = 'Code pending';

  /// [code], or [pendingCodeLabel] while there is none.
  String get displayCode => code ?? pendingCodeLabel;

  bool get hasCode => code != null;

  /// The offer's stored `donorCode` when it is a real PRC code, else null.
  ///
  /// Codes are assigned in sequence (DNR-0001, DNR-0002, ...; more digits
  /// after DNR-9999) from counters/donorCodes by the admin portal, or by the
  /// backend as a safety net. The app never makes one up: a locally
  /// derived code could equal another donor's real code, so the requester
  /// would see, and PRC would search for, the wrong donor.
  static String? donorCode(dynamic stored) {
    final s = stored?.toString().trim().toUpperCase() ?? '';
    return RegExp(r'^DNR-\d{4,}$').hasMatch(s) ? s : null;
  }
}

/// An approved blood request with its PRC-confirmed donors.
class RequestMatch {
  RequestMatch(
    this.request,
    List<MapEntry<String, Map<String, dynamic>>> offers,
  ) : donors = [
        for (final o in offers)
          if (OfferStatus.isConfirmed(o.value['status']?.toString()))
            MatchedDonor.fromOffer(o.key, o.value),
      ]..sort(_byConfirmed),
      pendingOffers = offers
          .where(
            (o) =>
                o.value['status']?.toString().trim().toLowerCase() ==
                OfferStatus.pending,
          )
          .length;

  final RequestProgress request;
  final List<MatchedDonor> donors;
  final int pendingOffers;

  /// Statuses PRC reached after approving the request: the ones listed in
  /// Matched Donors.
  static const listedStatuses = [
    RequestStatus.approved,
    RequestStatus.active,
    RequestStatus.matched,
    RequestStatus.fulfilled,
  ];

  static bool isListed(String? status) =>
      listedStatuses.contains(status?.trim().toLowerCase());

  static int _byConfirmed(MatchedDonor a, MatchedDonor b) {
    final x = a.confirmedAt, y = b.confirmedAt;
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return x.compareTo(y);
  }

  String get status => request.status;

  MatchState get state {
    if (donors.isNotEmpty ||
        status == RequestStatus.matched ||
        status == RequestStatus.fulfilled) {
      return MatchState.matched;
    }
    return pendingOffers > 0 ? MatchState.inProgress : MatchState.noMatch;
  }

  /// PRC fulfilled the request, or every confirmed donor has donated.
  bool get isCompleted =>
      status == RequestStatus.fulfilled ||
      (donors.isNotEmpty && donors.every((d) => d.donated));

  DateTime? get approvedAt => _date(request.data['reviewedAt']);

  DateTime? get matchedAt =>
      donors.map((d) => d.confirmedAt).nonNulls.firstOrNull ??
      _date(request.data['matchedAt']);

  DateTime? get completedAt {
    final fulfilled = _date(request.data['fulfilledAt']);
    if (fulfilled != null) return fulfilled;
    final donated = donors.map((d) => d.donatedAt).nonNulls.toList()..sort();
    return donated.lastOrNull;
  }

  /// List badge label.
  String get stateLabel => switch (state) {
    MatchState.matched => 'Matched Donor',
    MatchState.inProgress => 'Matching in Progress',
    MatchState.noMatch => 'No Match Yet',
  };

  /// Detail screen status pill.
  String get detailLabel => isCompleted
      ? 'Donation Completed'
      : state == MatchState.matched
      ? 'Donor Matched'
      : stateLabel;
}
