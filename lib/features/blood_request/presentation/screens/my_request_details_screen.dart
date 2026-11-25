import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/statuses.dart';
import '../../../donor/presentation/screens/matched_donor_detail_screen.dart';
import '../../data/blood_request_repository.dart';
import '../../domain/request_progress.dart';
import '../widgets/request_progress_widgets.dart';
import 'cancel_blood_request_screen.dart';
import 'post_blood_request_welcome_screen.dart';

/// Requester's view of one of their blood requests (Activity > View Request
/// Details).
///
/// PRC approves the request, confirms or declines donor offers and marks
/// the request fulfilled from the admin app (Item 5); here the requester
/// follows the status, sees offers read-only and may cancel while the
/// request is still in progress (the only change firestore.rules allow).
class MyRequestDetailsScreen extends StatefulWidget {
  const MyRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.userId,
    this.request,
    this.offers,
    this.cancel,
    this.onBackToActivity,
  });

  final String requestId;
  final String userId;

  /// Test hooks; default to Firestore.
  final Stream<Map<String, dynamic>?>? request;
  final Stream<List<Map<String, dynamic>>>? offers;
  final Future<void> Function(String reason)? cancel;

  /// Test hook for the Request Cancelled screen's Back to Activity button.
  final void Function(BuildContext context)? onBackToActivity;

  @override
  State<MyRequestDetailsScreen> createState() => _MyRequestDetailsScreenState();
}

class _MyRequestDetailsScreenState extends State<MyRequestDetailsScreen> {
  BloodRequestRepository? _repo;
  BloodRequestRepository get _repository => _repo ??= BloodRequestRepository();

  late final Stream<Map<String, dynamic>?> _request =
      widget.request ??
      FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(widget.requestId)
          .snapshots()
          .map((d) => d.data());

  Stream<List<Map<String, dynamic>>>? _offersStream;
  Stream<List<Map<String, dynamic>>> get _offers => _offersStream ??=
      widget.offers ??
      _repository
          .streamOffers(widget.requestId)
          .map((s) => [for (final d in s.docs) d.data()]);

  Future<void> _cancel(String reason) {
    final cancel = widget.cancel;
    if (cancel != null) return cancel(reason);
    return _repository.cancelRequest(
      requestId: widget.requestId,
      userId: widget.userId,
      reason: reason,
    );
  }

  /// Cancel Request screen, then Request Cancelled (which replaces it).
  void _openCancel(RequestProgress progress) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CancelBloodRequestScreen(
          reference: progress.reference,
          cancel: _cancel,
          onBackToActivity: widget.onBackToActivity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Request Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _request,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this request.'));
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: requestRed),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('This request no longer exists.'));
          }
          final p = RequestProgress.fromFirestore(widget.requestId, data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _Header(progress: p),
              const SizedBox(height: 16),
              RequestStatusCallout(p, heading: 'Current Status'),
              const SizedBox(height: 16),
              RequestCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RequestSectionTitle('Request Progress'),
                    RequestProgressTimeline(steps: p.steps),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RequestCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RequestSectionTitle('Request Information'),
                    RequestInfoRows(
                      rows: [
                        ...RequestInfoRows.basic(p),
                        if (p.component != null)
                          ('Component', RequestInfoRows.value(p.component!)),
                        if (p.patientName != null)
                          ('Patient', RequestInfoRows.value(p.patientName!)),
                        (
                          'Submitted',
                          RequestInfoRows.value(formatRequestDate(p.createdAt)),
                        ),
                        if (p.notes != null)
                          ('Notes', RequestInfoRows.value(p.notes!)),
                      ],
                    ),
                  ],
                ),
              ),
              if (p.hasOffersStage) ...[
                const SizedBox(height: 16),
                _OffersCard(
                  offers: _offers,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MatchedDonorDetailScreen(requestId: widget.requestId),
                    ),
                  ),
                ),
              ],
              if (p.isRejected) ...[
                const SizedBox(height: 16),
                RequestCardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RequestSectionTitle('Submit Again'),
                      const Text(
                        'Fix the issue PRC described above and submit a new '
                        'request.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const PostBloodRequestWelcomeScreen(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: requestRed,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit a New Request'),
                      ),
                    ],
                  ),
                ),
              ],
              if (p.canCancel) ...[
                const SizedBox(height: 16),
                RequestCardShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RequestSectionTitle('Cancel Request'),
                      const Text(
                        'No longer need blood? Cancel the request so PRC and '
                        'donors stop working on it.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _openCancel(p),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: requestRed,
                          side: const BorderSide(color: requestRed),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Request Cancellation'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.progress});

  final RequestProgress progress;

  @override
  Widget build(BuildContext context) {
    return RequestCardShell(
      child: Row(
        children: [
          BloodTypeBadge(progress.bloodType, size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.reference,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Blood Request',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    RequestStatusChip(progress),
                    if (progress.isUrgent) const UrgentBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only summary of donor offers; PRC confirms or declines them.
class _OffersCard extends StatelessWidget {
  const _OffersCard({required this.offers, required this.onOpen});

  final Stream<List<Map<String, dynamic>>> offers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: offers,
      builder: (context, snapshot) {
        final list = snapshot.data ?? const [];
        final waiting = list
            .where((o) => o['status'] == OfferStatus.pending)
            .length;
        final confirmed = list
            .where((o) => OfferStatus.isConfirmed(o['status']?.toString()))
            .length;
        final summary = snapshot.hasError
            ? 'Could not load donor offers.'
            : !snapshot.hasData
            ? 'Loading donor offers...'
            : list.isEmpty
            ? 'No donor offers yet.'
            : '${list.length} ${list.length == 1 ? 'offer' : 'offers'} · '
                  '$confirmed confirmed by PRC · $waiting waiting for PRC';
        return RequestCardShell(
          padding: EdgeInsets.zero,
          child: ListTile(
            onTap: onOpen,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: const Icon(
              Icons.volunteer_activism_outlined,
              color: requestRed,
            ),
            title: const Text(
              'Matched Donor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$summary\nPRC confirms the donor; you see an anonymised code.',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
