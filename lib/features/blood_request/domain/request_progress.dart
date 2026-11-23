import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/statuses.dart';
import '../../history/domain/history_entries.dart';

/// How a step of the Request Progress timeline is drawn.
enum ProgressStepState { done, active, upcoming, stopped }

/// Colour family for chips and callouts.
enum ProgressTone { amber, blue, green, red, grey }

class ProgressStep {
  const ProgressStep(this.title, this.subtitle, this.state);

  final String title;
  final String subtitle;
  final ProgressStepState state;
}

/// A blood request as the requester sees it in Activity and Request
/// Details: chip label, status callout and the 4-step progress, all derived
/// from the live `status` (PRC drives every change after submission).
class RequestProgress {
  RequestProgress._({
    required this.id,
    required this.data,
    required this.status,
  });

  factory RequestProgress.fromFirestore(String id, Map<String, dynamic> data) =>
      RequestProgress._(
        id: id,
        data: data,
        status:
            data['status']?.toString().trim().toLowerCase() ??
            RequestStatus.pending,
      );

  final String id;
  final Map<String, dynamic> data;
  final String status;

  static const prc = 'PRC-Sorsogon';

  /// Requests shown in the Activity tab: still in progress, or rejected
  /// (the requester may read the reason and submit again). Everything else
  /// is in History.
  static bool showInActivity(String? status) {
    final s = status?.trim().toLowerCase();
    return RequestStatus.isInProgress(s) || s == RequestStatus.rejected;
  }

  String? _text(String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  DateTime? get createdAt => _date(data['createdAt']);
  DateTime? get neededBy =>
      _date(data['neededByDate'] ?? data['requiredDate'] ?? data['neededBy']);

  String get reference => historyReference('BR', id, createdAt);
  String get bloodType => (_text('bloodType') ?? '—').toUpperCase();

  int get units {
    final v = data['unitsRequired'] ?? data['unitsNeeded'];
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 1;
  }

  String get unitsText => unitsLabel(units);

  String get hospital =>
      _text('hospitalName') ?? _text('hospital') ?? 'Not specified';

  /// Requests do not store a separate location today; older ones may.
  String get location =>
      _text('hospitalAddress') ?? _text('hospitalLocation') ?? 'Not specified';

  /// Blood-Connect stores urgency as `urgency: 'Urgent' | 'Normal'`.
  bool get isUrgent => data['urgency'] == RequestUrgency.urgent;
  String get urgencyText => isUrgent ? 'Urgent' : 'Normal';

  String? get component => _text('component');
  String? get patientName => _text('patientName');
  String? get notes => _text('notes');
  String? get rejectionReason =>
      _text('rejectionReason') ?? _text('adminNotes');
  String? get cancellationReason => _text('cancellationReason');

  bool get canCancel => RequestStatus.canBeCancelled(status);
  bool get isRejected => status == RequestStatus.rejected;

  /// Donor offers exist only once PRC opened the request to donors.
  bool get hasOffersStage =>
      status != RequestStatus.pending && status != RequestStatus.rejected;

  String get chipLabel => switch (status) {
    RequestStatus.pending => 'Under Review',
    RequestStatus.approved || RequestStatus.active => 'Finding Donors',
    RequestStatus.matched => 'Donor Matched',
    RequestStatus.fulfilled => 'Fulfilled',
    RequestStatus.rejected => 'Not Approved',
    RequestStatus.cancelled => 'Cancelled',
    RequestStatus.expired => 'Expired',
    _ => RequestStatus.label(status),
  };

  ProgressTone get tone => switch (status) {
    RequestStatus.pending => ProgressTone.amber,
    RequestStatus.approved || RequestStatus.active => ProgressTone.blue,
    RequestStatus.matched || RequestStatus.fulfilled => ProgressTone.green,
    RequestStatus.rejected => ProgressTone.red,
    _ => ProgressTone.grey,
  };

  String get calloutTitle => switch (status) {
    RequestStatus.pending => 'Checking Blood Availability',
    RequestStatus.approved || RequestStatus.active => 'Looking for Donors',
    RequestStatus.matched => 'Donor Confirmed',
    RequestStatus.fulfilled => 'Request Fulfilled',
    RequestStatus.rejected => 'Request Not Approved',
    RequestStatus.cancelled => 'Request Cancelled',
    RequestStatus.expired => 'Request Expired',
    _ => RequestStatus.label(status),
  };

  String get calloutMessage => switch (status) {
    RequestStatus.pending =>
      '$prc is reviewing your request and checking the blood bank for '
          'available units. You will be notified of the result.',
    RequestStatus.approved || RequestStatus.active =>
      '$prc approved your request and opened it to donors with a matching '
          'blood type. You will be notified when PRC confirms a donor.',
    RequestStatus.matched =>
      '$prc has confirmed a donor for your request and will coordinate the '
          'blood release. PRC marks the request fulfilled once blood is '
          'released.',
    RequestStatus.fulfilled =>
      '$prc has marked this request as fulfilled. We hope the patient '
          'recovers soon.',
    RequestStatus.rejected =>
      rejectionReason ??
          '$prc could not approve this request. You may submit a new one.',
    RequestStatus.cancelled =>
      cancellationReason == null
          ? 'This request was cancelled.'
          : 'This request was cancelled: $cancellationReason',
    RequestStatus.expired =>
      'This request closed after its needed-by date or after 7 days. '
          'Submit a new request if blood is still needed.',
    _ => 'Status: ${RequestStatus.label(status)}',
  };

  /// Request Submitted → Under Review → Donor Matching → Fulfilled.
  List<ProgressStep> get steps {
    // How far the request got: 1 = submitted ... 4 = fulfilled.
    final reached = switch (status) {
      RequestStatus.pending => 1,
      RequestStatus.approved || RequestStatus.active => 2,
      RequestStatus.matched => 3,
      RequestStatus.fulfilled => 4,
      RequestStatus.rejected => 1,
      // Closed early: show how far it got before closing.
      _ => data['reviewedAt'] != null ? 2 : 1,
    };
    final stoppedAt = switch (status) {
      RequestStatus.rejected => 1, // review failed
      RequestStatus.cancelled || RequestStatus.expired => reached,
      _ => null,
    };

    ProgressStepState stateOf(int index) {
      if (stoppedAt != null) {
        if (index < stoppedAt) return ProgressStepState.done;
        if (index == stoppedAt) return ProgressStepState.stopped;
        return ProgressStepState.upcoming;
      }
      if (index < reached) return ProgressStepState.done;
      if (index == reached) {
        return status == RequestStatus.fulfilled
            ? ProgressStepState.done
            : ProgressStepState.active;
      }
      return ProgressStepState.upcoming;
    }

    return [
      ProgressStep(
        'Request Submitted',
        'Your request was sent to $prc.',
        ProgressStepState.done,
      ),
      ProgressStep(
        'Under Review by $prc',
        isRejected
            ? 'PRC did not approve this request.'
            : 'PRC checks your documents and blood availability.',
        stateOf(1),
      ),
      ProgressStep(
        'Donor Matching (if needed)',
        'If blood is not available, PRC finds a matching donor.',
        stateOf(2),
      ),
      ProgressStep(
        'Request Fulfilled',
        'PRC releases the blood and closes the request.',
        stateOf(3),
      ),
    ];
  }
}
