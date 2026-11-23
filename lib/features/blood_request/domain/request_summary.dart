import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';
import '../../history/domain/history_entries.dart';

/// `request_summaries/{requestId}`: the anonymised, donor-facing copy of a
/// blood request that PRC publishes on approval (blood-connect-admin) and
/// the backend keeps in sync (expiry, cancellation, account deletion).
///
/// It never contains the patient's identity, the requester's contact
/// details, the diagnosis or the Blood Request Form, so donors read this and
/// never `blood_requests` (which only the owner and PRC may read).
class RequestSummary {
  const RequestSummary({
    required this.id,
    required this.status,
    required this.bloodType,
    required this.units,
    this.component,
    this.urgency,
    this.hospitalName,
    this.neededBy,
    this.createdAt,
  });

  final String id;
  final String status;
  final String bloodType;
  final int units;
  final String? component;
  final String? urgency;

  /// Copied by PRC on approval; older summaries may not have it.
  final String? hospitalName;
  final DateTime? neededBy;
  final DateTime? createdAt;

  static String? _text(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory RequestSummary.fromFirestore(String id, Map<String, dynamic> data) {
    final units = data['unitsRequired'];
    return RequestSummary(
      id: id,
      status: _text(data['status'])?.toLowerCase() ?? '',
      bloodType: (_text(data['bloodType']) ?? '').toUpperCase(),
      units: units is num ? units.toInt() : int.tryParse('$units') ?? 1,
      component: _text(data['component']),
      urgency: _text(data['urgency']),
      hospitalName: _text(data['hospitalName']),
      neededBy: _date(data['neededByDate']),
      createdAt: _date(data['createdAt']),
    );
  }

  bool get isOpen => RequestStatus.isOpenToDonors(status);
  bool get isUrgent => urgency == RequestUrgency.urgent;
  String get hospital => hospitalName ?? 'Hospital shared by PRC';

  /// "BR-20261120-ABC", the same reference the requester sees.
  String get reference => historyReference('BR', id, createdAt);

  /// "A+ · 1 unit"
  String get typeAndUnits => '$bloodType · ${unitsLabel(units)}';

  /// Fields copied onto a new offer so the donor's offer list can show
  /// them without reading the request.
  Map<String, dynamic> offerFields() => {
    'requestBloodType': bloodType,
    'component': component,
    'urgency': urgency,
    'neededByDate': neededBy == null ? null : Timestamp.fromDate(neededBy!),
    'hospitalName': hospitalName,
  };
}
