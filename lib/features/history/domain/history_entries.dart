import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';
import '../../../core/utils/blood_compatibility.dart';

/// Facility shown when a donation has no hospital on record.
const prcFacility = 'Philippine Red Cross - Sorsogon';

/// Reads a Firestore date: a [Timestamp], a [DateTime], or a
/// `YYYY-MM-DD` / ISO string. Returns null for anything else.
DateTime? readHistoryDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

/// `PREFIX-YYYYMMDD-XXX`, where XXX is the start of the document id.
String historyReference(String prefix, String docId, DateTime? date) {
  final d = date ?? DateTime.fromMillisecondsSinceEpoch(0);
  final ymd =
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
  final suffix = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  final short = suffix.length >= 3
      ? suffix.substring(0, 3)
      : suffix.padRight(3, '0');
  return '$prefix-$ymd-$short';
}

String? _text(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

int _units(dynamic value, {int fallback = 1}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String unitsLabel(int units) => units == 1 ? '1 unit' : '$units units';

/// A closed blood request (fulfilled, cancelled, expired or rejected).
class RequestHistoryEntry {
  const RequestHistoryEntry({
    required this.id,
    required this.status,
    required this.bloodType,
    required this.units,
    required this.hospital,
    this.component,
    this.patientName,
    this.createdAt,
    this.closedAt,
    this.neededBy,
    this.reason,
  });

  /// Request statuses that belong in History rather than Activity.
  static const pastStatuses = {
    RequestStatus.fulfilled,
    RequestStatus.cancelled,
    RequestStatus.expired,
    RequestStatus.rejected,
  };

  final String id;
  final String status;
  final String bloodType;
  final int units;
  final String hospital;
  final String? component;
  final String? patientName;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final DateTime? neededBy;

  /// Why it was cancelled or rejected, when recorded.
  final String? reason;

  String get reference => historyReference('BR', id, createdAt);

  /// "A+ · 1 unit"
  String get summary => '$bloodType · ${unitsLabel(units)}';

  /// The date shown on the card: when the request was made.
  DateTime? get date => createdAt ?? closedAt;

  /// Null when the request is still in progress (it belongs in Activity).
  static RequestHistoryEntry? fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final status = data['status']?.toString().trim().toLowerCase() ?? '';
    if (!pastStatuses.contains(status)) return null;

    final closedAt = readHistoryDate(
      switch (status) {
            RequestStatus.fulfilled => data['fulfilledAt'],
            RequestStatus.cancelled => data['cancelledAt'],
            RequestStatus.expired => data['expiredAt'],
            _ => data['reviewedAt'] ?? data['rejectedAt'],
          } ??
          data['updatedAt'],
    );

    return RequestHistoryEntry(
      id: id,
      status: status,
      bloodType: _text(data['bloodType']) ?? '—',
      units: _units(data['unitsRequired'] ?? data['unitsNeeded']),
      hospital:
          _text(data['hospitalName']) ??
          _text(data['hospitalLocation']) ??
          _text(data['hospital']) ??
          'Hospital not specified',
      component: _text(data['component']),
      patientName: _text(data['patientName']),
      createdAt: readHistoryDate(data['createdAt']),
      closedAt: closedAt,
      neededBy: readHistoryDate(
        data['neededByDate'] ?? data['requiredDate'] ?? data['neededBy'],
      ),
      reason: _text(
        data['cancellationReason'] ??
            data['cancelReason'] ??
            data['rejectionReason'],
      ),
    );
  }

  /// Newest first; requests without a date go last.
  static List<RequestHistoryEntry> fromDocs(
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) {
    final list = [for (final doc in docs) ?fromFirestore(doc.key, doc.value)];
    list.sort((a, b) => _newestFirst(a.date, b.date));
    return list;
  }
}

/// Where a donation record came from.
enum DonationSource {
  /// A donor offer on a blood request (`blood_requests/{id}/offers`).
  offer,

  /// The collection PRC recorded when activating the donor
  /// (`donors/{uid}.collection`).
  donorActivation,
}

/// A finished donation, or a past offer that did not lead to one.
class DonationHistoryEntry {
  const DonationHistoryEntry({
    required this.id,
    required this.source,
    required this.status,
    required this.bloodType,
    required this.donationType,
    required this.units,
    required this.facility,
    this.date,
    this.requestId,
    this.notes,
  });

  /// Offer statuses that belong in History.
  static const pastOfferStatuses = {
    OfferStatus.donated,
    OfferStatus.withdrawn,
    OfferStatus.rejected,
  };

  final String id;
  final DonationSource source;

  /// An [OfferStatus] value; the activation collection counts as donated.
  final String status;
  final String bloodType;
  final String donationType;
  final int units;
  final String facility;
  final DateTime? date;
  final String? requestId;
  final String? notes;

  bool get isCompleted => status == OfferStatus.donated;

  String get reference => historyReference('DON', id, date);

  /// "A+ · Whole Blood (1 unit)"
  String get summary => '$bloodType · $donationType (${unitsLabel(units)})';

  /// Null for offers that are still in progress (they belong in Activity).
  static DonationHistoryEntry? fromOffer(String id, Map<String, dynamic> data) {
    final status = data['status']?.toString().trim().toLowerCase() ?? '';
    if (!pastOfferStatuses.contains(status)) return null;

    final date = readHistoryDate(
      switch (status) {
            OfferStatus.donated => data['donatedAt'],
            OfferStatus.withdrawn => data['withdrawnAt'],
            _ => data['rejectedAt'],
          } ??
          data['updatedAt'] ??
          data['createdAt'],
    );

    return DonationHistoryEntry(
      id: id,
      source: DonationSource.offer,
      status: status,
      bloodType:
          _text(data['donorBloodType']) ??
          _text(data['requestBloodType']) ??
          '—',
      donationType: _text(data['component']) ?? 'Whole Blood',
      units: _units(data['units'], fallback: 1),
      facility: _text(data['hospitalName']) ?? prcFacility,
      date: date,
      requestId: _text(data['requestId']),
    );
  }

  /// The first donation PRC recorded on the donor profile, if completed.
  static DonationHistoryEntry? fromDonorProfile(
    String uid,
    Map<String, dynamic>? donor,
  ) {
    final collection = donor?['collection'];
    if (collection is! Map) return null;
    final completed =
        collection['status'] == 'completed' ||
        donor?['collectionStatus'] == 'completed';
    if (!completed) return null;

    return DonationHistoryEntry(
      id: uid,
      source: DonationSource.donorActivation,
      status: OfferStatus.donated,
      bloodType: _text(donor?['bloodType']) ?? '—',
      donationType: 'Whole Blood',
      units: _units(collection['units'], fallback: 1),
      facility: prcFacility,
      date: readHistoryDate(collection['date']),
      notes: _text(collection['notes']),
    );
  }

  /// Offers plus the activation donation, newest first.
  static List<DonationHistoryEntry> combine({
    required String uid,
    required Iterable<MapEntry<String, Map<String, dynamic>>> offers,
    Map<String, dynamic>? donor,
  }) {
    final list = [
      for (final offer in offers) ?fromOffer(offer.key, offer.value),
      ?fromDonorProfile(uid, donor),
    ];
    list.sort((a, b) => _newestFirst(a.date, b.date));
    return list;
  }
}

/// Totals and the next eligible date for the Donation History header.
class DonationSummary {
  const DonationSummary({
    required this.completedCount,
    this.lastDonation,
    this.nextEligible,
  });

  final int completedCount;
  final DateTime? lastDonation;
  final DateTime? nextEligible;

  bool isEligible({DateTime? today}) =>
      DonationInterval.isEligible(nextEligible, today: today);

  /// [donor] is `donors/{uid}`; PRC's `nextEligibleDonationDate` wins over
  /// the 56-day estimate from the latest donation.
  factory DonationSummary.from(
    List<DonationHistoryEntry> entries, {
    Map<String, dynamic>? donor,
  }) {
    final completed = entries.where((e) => e.isCompleted).toList();

    DateTime? last = readHistoryDate(donor?['lastDonationDate']);
    for (final entry in completed) {
      final d = entry.date;
      if (d != null && (last == null || d.isAfter(last))) last = d;
    }

    final prcNext = donor == null
        ? null
        : DonorEligibility.nextEligibleDate(donor);

    return DonationSummary(
      completedCount: completed.length,
      lastDonation: last,
      nextEligible: DonationInterval.nextEligibleDate(
        lastDonation: last,
        prcNextEligible: prcNext,
      ),
    );
  }
}

int _newestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
