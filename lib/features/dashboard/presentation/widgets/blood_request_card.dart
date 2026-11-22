import 'package:flutter/material.dart';

import '../../../../core/constants/statuses.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../blood_request/data/blood_request_repository.dart';
import '../../../blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import '../../../blood_request/presentation/screens/request_offers_screen.dart';
import '../../../requests/presentation/request_rejection_screen.dart';
import 'activity_helpers.dart';

/// One of the requester's blood requests, with its status and actions:
/// view offers, cancel, or read PRC's rejection reason.
class BloodRequestCard extends StatelessWidget {
  const BloodRequestCard({
    super.key,
    required this.requestId,
    required this.data,
    required this.userId,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final String userId;

  String get _status =>
      (data['status'] as String? ?? RequestStatus.pending).toLowerCase();

  String get _title => 'Blood request for ${data['bloodType'] ?? '—'}';

  static Color statusColor(String status) {
    switch (status) {
      case RequestStatus.approved:
      case RequestStatus.active:
      case RequestStatus.matched:
        return Colors.green;
      case RequestStatus.fulfilled:
        return Colors.teal;
      case RequestStatus.rejected:
        return AppColors.primaryRed;
      case RequestStatus.cancelled:
      case RequestStatus.expired:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final reason = await confirmActivityAction(
      context,
      title: 'Cancel this request?',
      message:
          'Donors will no longer see it and PRC will stop matching donors. '
          'This cannot be undone.',
      confirmLabel: 'Cancel request',
      withReason: true,
    );
    if (reason == null || !context.mounted) return;

    Object? error;
    try {
      await BloodRequestRepository().cancelRequest(
        requestId: requestId,
        userId: userId,
        reason: reason,
      );
    } catch (e) {
      error = e;
    }
    if (context.mounted) {
      showActivityResult(context, error, 'Your blood request was cancelled.');
    }
  }

  void _openRejection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestRejectionScreen(
          title: _title,
          reason:
              data['rejectionReason'] as String? ??
              data['adminNotes'] as String? ??
              'No specific notes provided by the administrator.',
          onResubmit: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PostBloodRequestWelcomeScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openOffers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestOffersScreen(
          requestId: requestId,
          title: 'Offers · $_title',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final neededBy = formatActivityDate(data['neededByDate']);
    final details = [
      if (data['urgency'] == RequestUrgency.urgent) 'Urgent',
      if (data['component'] != null) data['component'].toString(),
      if (neededBy != null) 'Needed by $neededBy',
    ].join(' · ');
    final showOffers =
        status != RequestStatus.pending && status != RequestStatus.rejected;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  RequestStatus.label(status),
                  style: TextStyle(
                    color: statusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
            Row(
              children: [
                if (status == RequestStatus.rejected)
                  TextButton(
                    onPressed: () => _openRejection(context),
                    child: const Text('View reason'),
                  ),
                if (showOffers)
                  TextButton(
                    onPressed: () => _openOffers(context),
                    child: const Text('View offers'),
                  ),
                const Spacer(),
                if (RequestStatus.canBeCancelled(status))
                  TextButton(
                    onPressed: () => _cancel(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryRed,
                    ),
                    child: const Text('Cancel request'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
